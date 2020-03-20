module websocketservice;

import vibe.vibe;

class WebsocketService {
    @path("/") void getHome()
	{
        logInfo("redirecting to index.html");
		redirect("/index.html");
    }

	@path("/ws") void getWebsocket(scope WebSocket socket){
		int counter = 0;
		logInfo("Got new web socket connection.");
		while (true) {
			sleep(1.seconds);
			if (!socket.connected) break;
			counter++;
			logInfo("Sending '%s'.", counter);
			socket.send(counter.to!string);
		}
		logInfo("Client disconnected.");
	}
}
