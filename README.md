
# **Realtime STT and Translation** 
![Logo](https://onewordmanytongues.com/static/favicon.ico)

A deployable Docker container to transcribe and translate a live RTMP stream.

## **Deployment**
One Word Many Tongues is easy to integrate into existing AV setups.

### **ARM64 (Raspberry Pi 5)**
<img width="1488" height="947" alt="68747470733a2f2f6f6e65776f72646d616e79746f6e677565732e636f6d2f7374617469632f72617370626572727970692e706e67 (1)" src="https://github.com/user-attachments/assets/5cc7e159-79b8-4723-b0b1-272b1362f9f5" />

\
The lightweight Docker container for the Raspberry Pi 5 is built on [Ubuntu 24.04](https://hub.docker.com/_/Ubuntu). Setup is simple, just connect the Raspberry Pi with the appropiate Docker container to the same network as your streaming computer. Once the Raspberry Pi is connected just point an RTMP stream to the Raspberry Pi and it will begin to transcribe text in realtime.

#### Pros
✅ Easy to setup\
✅ Realtime translations\
✅ Secure. No audio leaves the local network\
✅ Lower recurring costs compared to cloud solutions\
#### Cons
❌ Expensive setup cost ($100 CAD for Raspberry Pi)\
❌ Smaller transcription due to processing limitations\
❌ Harder to troubleshoot problems while deployed

### **CUDA (Cloud based GPU)**
<img width="1738" height="1022" alt="image (1)" src="https://github.com/user-attachments/assets/b8c332a2-ea8e-404f-900b-eb2c97062125" />

\
The robust server based translation Docker container is built on [nvidia's CUDA docker container](https://hub.docker.com/r/nvidia/cuda). This system allows for multiple streams from multiple locations. It can recieve multiple streams and use parallelized GPU workers to transcribe and translate the text whilst simaltaneously pushing the text to https://onewordmanytongues.com.

To use this system simply send an RTMP stream to the server and the server will manage multiple streams and transcription workers making sure no audio or text is lost.

#### Pros
✅ Easy to setup\
✅ Realtime translations\
✅ Lower setup cost, only pay for using the system.\
✅ Highest possible transcription quality.\
✅ Easy to debug errors.\
✅ Cost can be distributed over multiple clients
#### Cons
❌ Higher recurring costs\
❌ Less secure, audio does leave the local network\
❌ Costs can balloon as cloud GPUs are expensive\
❌ Slower startup time, the server cannot be always running


## Resources Used

 - [eraser](https://eraser.io) for architecture diagrams.
 - [AWS](https://aws.amazon.com/) for web hosting, translation, and configuration storage.
 - [Runpod](https://runpod.io) for cloud GPUs
 - `faster-whisper` for transcription
 - `nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04` for CUDA docker base
 - `ubuntu` for ARM docker base

