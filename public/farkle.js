window.onload = function(){

    let ws = new WebSocket("ws://" + location.host + "/ws");
    ws.onmessage = function(m){ console.log(m); };

    
    
}
