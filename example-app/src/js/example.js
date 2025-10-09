import { VideoPlayer } from '@capgo/video-player';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    VideoPlayer.echo({ value: inputValue })
}
