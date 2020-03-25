import vibe.vibe;

import websocketservice;

void main()
{
    auto router = new URLRouter;
    router.registerWebInterface(new WebsocketService);

    router.get("*", serveStaticFiles("public/"));
    
    auto settings = new HTTPServerSettings;
    settings.port = environment.get("PORT", "8080").to!ushort;
	listenHTTP(settings, router);

	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
	runApplication();
}



//check reset turnScore on newRoll
//update coloring on mid-tern newRoll
