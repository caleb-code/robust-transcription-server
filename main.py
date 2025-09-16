from faster_whisper import WhisperModel
import numpy as np
import asyncio
from quart import Quart, request
import requests
import boto3
import json
import s3fs

app = Quart(__name__)

fs = s3fs.S3FileSystem(anon=False, key="*******REMOVED*******", secret="*******REMOVED*******")

translate_client = boto3.client(
    "translate",
    region_name="us-west-2",
    aws_access_key_id="*******REMOVED*******",
    aws_secret_access_key="*******REMOVED*******",
)


def create_target_languages():
    target_languages = {}
    for i in fs.ls("configs-transcription"):
        if i.endswith(".json"):
            id = i.split("/")[1].split(".json")[0]
            print(id)
            with fs.open(i) as f:
                langs = json.load(f)
                target_languages[id] = langs
    return target_languages


async def translate(text, target_lang, source_lang="en"):
    response = await asyncio.to_thread(
        translate_client.translate_text,
        Text=text,
        SourceLanguageCode=source_lang,
        TargetLanguageCode=target_lang,
    )
    return response["TranslatedText"]


async def post_process(text, target_languages):
    text, id = text
    translated = {}
    languages = target_languages[id]
    for lang in languages["LANGUAGES"].split(","):
        translated[lang] = await translate(text, target_lang=lang)
    return translated


class GPUWorker:
    def __init__(
        self,
        audio_queue,
        name,
        target_languages,
        device="cuda",
        model_size="turbo",
        compute_type="float16",
    ):
        self.model = WhisperModel(model_size, device=device, compute_type=compute_type)
        self.audio_queue = audio_queue
        self.name = name
        self.target_languages = target_languages

    async def run(self):
        while True:
            latest, id = await self.audio_queue.get()
            segments, _ = await asyncio.to_thread(self.model.transcribe, latest)
            text = await asyncio.to_thread(self.merge, segments)
            if text != "":
                processed_data = await post_process([text, id], self.target_languages)
                print(processed_data)
                await asyncio.to_thread(send_to_server, processed_data, id)
            else:
                continue

    def merge(self, segments):
        return " ".join(seg.text for seg in segments).strip()


async def producer(audio_queue, stream_url=None, buffer_seconds=8, id=0):
    if not stream_url:
        raise ValueError("Please provide a stream URL")

    ffmpeg_cmd = [
        "ffmpeg",
        "-i",
        f"rtmp://127.0.0.1:1935/live/{stream_url}",
        "-vn",
        "-ac",
        "1",
        "-ar",
        "16000",
        "-f",
        "s16le",
        "pipe:1",
    ]

    process = await asyncio.create_subprocess_exec(
        *ffmpeg_cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
    )

    while True:
        audio_data = await process.stdout.read(buffer_seconds * 16000 * 2)
        if not audio_data:
            break
        audio_array = np.frombuffer(audio_data, np.int16).astype(np.float32) / 32768.0
        await audio_queue.put([audio_array, id])
        await asyncio.sleep(buffer_seconds * 0.8)


def send_to_server(payload, id):
    server_url = "https://onewordmanytongues.com/api"
    license_key = id
    if not server_url or not license_key:
        print("[Send] SERVER_URL or LICENSE_KEY missing")
        return
    headers = {
        "Authorization": f"Bearer {license_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    try:
        resp = requests.post(server_url, json=payload, headers=headers, timeout=10)
        if resp.status_code != 200:
            print(
                f"[Send] Server responded with status {resp.status_code}: {resp.text}"
            )
    except Exception as e:
        print(f"[Send] Exception sending to server: {e}")


@app.route("/on_publish", methods=["POST"])
async def on_publish():
    data = await request.form
    stream_url = data.get("name")
    if not stream_url:
        return "Missing stream URL", 400
    if not stream_url in create_target_languages().keys():
        return "Stream not allowed", 403
    audio_queue = app.config.get("audio_queue")

    asyncio.create_task(producer(audio_queue, stream_url=stream_url, id=stream_url))

    return "Stream started", 200


async def main():
    audio_queue = asyncio.Queue()
    target_languages = create_target_languages()
    workers = [
        GPUWorker(
            audio_queue,
            f"worker_{i}",
            target_languages,
            model_size="turbo",
            device="cuda",
            compute_type="float16",
        )
        for i in range(3)
    ]
    for w in workers:
        asyncio.create_task(w.run())
    app.config["audio_queue"] = audio_queue
    asyncio.create_task(app.run_task(host="127.0.0.1", port=8080))
    while True:
        await asyncio.sleep(1)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Exiting...")