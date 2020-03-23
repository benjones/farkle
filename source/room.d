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
    LogEntry[] log;

    void join(string name, WebSocket socket){
        farkle.addPlayer(Player(name, 0, socket));
        if(farkle.isMyTurn(socket)){
            farkle.messageActivePlayer(farkle.legalMoves);
        }
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
        logInfo("player %s taking turn with command: %s", player, command);
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
        } else if(ts == "Steal"){
            move = Steal();
        } else {
            logInfo("unknown command type");
            assert(false);
        }
        logInfo("turn: %s", command);
        if(farkle.isLegalMove(move)){
            farkle.takeAction(move);
        }

        farkle.messageAllPlayers(farkle.toJson);
        farkle.messageActivePlayer(farkle.legalMoves);
        
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
