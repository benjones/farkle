module room;

import farkle;
import vibe.core.sync : LocalManualEvent, createManualEvent;
import vibe.http.websockets : WebSocket;
import vibe.data.json;
import vibe.core.log;

struct LogEntry {
    Player player;
    Move move;
}

class Room {
    
    Farkle farkle;
    LocalManualEvent roomEvent;
    LogEntry[] log;

    this(){
        roomEvent = createManualEvent;
    }
    
    void join(string name, WebSocket socket){
        farkle.addPlayer(Player(name, 0, socket));
    }

    void leave(WebSocket socket){
        farkle.removePlayer(socket);
    }

    bool isMyTurn(WebSocket socket){
        return farkle.isMyTurn(socket);
    }
    
    void takeTurn(WebSocket ws, Json command){
        import std.algorithm : map;
        import std.array;
        
        auto player = farkle.getPlayer(ws);
        logInfo("player ", player, " taking turn with command: ", command);
        Move move;
        auto type = command["type"];
        if(type.type != Json.Type.string){
            logInfo("no type!");
            assert(false);
        }

        auto ts = type.get!string;

        if(ts == "Roll"){
            auto newHoldsJson = command["newHolds"];
            if(newHoldsJson.type != Json.Type.array){
                logInfo("no newHolds");
                assert(false);
            }
            auto newHolds = newHoldsJson.get!(Json[]).map!(a => a.get!int).array;
            move = Roll(newHolds);
        } else if(ts == "Stay"){
            move = Stay();
        } else if(ts == "NewRoll"){
            move = NewRoll();
        } else {
            logInfo("unknown command type");
            assert(false);
        }
        logInfo("turn: ", command);
        farkle.takeAction(move);
    }

    Json listenForBroadcast(){
        roomEvent.wait();
        return farkle.toJson;
    }
}

Room getRoom(){
    static Room room;
    if(!room){
        logInfo("making new room");
        room = new Room();
    }
    logInfo("room: ", room);
    return room;
}
