import { VideoPlayer } from '@capgo/capacitor-video-player';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    VideoPlayer.echo({ value: inputValue })
}
