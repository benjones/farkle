///Data structures for the game and functions that operate on it
module farkle;


struct Die {

    int showing;
    bool held; 
}

struct Player {
    import vibe.http.websockets : WebSocket;
    string name;
    int score;
    WebSocket ws;
}

struct Roll {
    int[] newHolds;
}

struct LabeledScore {
    int score;
    string description;
}

struct Farkle {
    private{
        Die[6] dice;
        Player[] players;
        size_t whoseTurn;
    }

    void addPlayer(Player p){
        import std.array : insertInPlace;
        import std.range : empty;
        if(players.empty){
            players = [p];
            newTurn();
        } else {
            players.insertInPlace(whoseTurn + 1, p);
        }
    }

    void roll(Roll roll){
        import std.random : uniform;
        
        foreach(hold; roll.newHolds){
            dice[hold].held = true;
        }
        foreach(ref die; dice){
            if(!die.held){
                die.showing = uniform!"[]"(1,6);
            }
        }
    }

    //start who's turn clean by rolling all 6 dice
    void newTurn(){
        foreach(ref die; dice){
            die.held = false;
        }
        roll(Roll([]));
    }

    
    LabeledScore scoreRoll(){
        import std.algorithm;
        import std.array;
        import std.conv : to;
        import std.stdio;
        
        int[] toScore = dice[].filter!(x => !x.held).map!(x => x.showing).array;
        sort(toScore);

        auto groups = toScore.group.array.sort!((a, b) => a[1] > b[1]);
        writeln("groups: ", groups);
        if(groups.length == 6){
            //straight
            return LabeledScore(3000, "straight");
        } else if(groups[0][1] == 5){
            return LabeledScore(300*groups[0][0], "five " ~ to!string(groups[0][0]) ~ "'s");
        } else if (groups[0][1] == 4){
            if(groups[1][1] == 2){
                return LabeledScore(1500, "three doublets");
            } else {
                return LabeledScore(200*groups[0][0], "four " ~ to!string(groups[0][0]) ~ "'s");
            }
        } else if (groups[0][1] == 3) {
            if(groups[1][1] == 3){
                return LabeledScore(2500, "two triplets");
            } else {
                return LabeledScore(100*groups[0][0], "three " ~ to!string(groups[0][0]) ~ "'s");
            }
        } else if(groups[2][1] == 2) {
            return LabeledScore(1500, "three doublets");
        } else {
            return LabeledScore(0, "farkle");
        }
    }
    
    bool farkled(){
        return false;
    }
}


unittest {

    import std.stdio;
    
    Farkle f;

    Player p;

    f.addPlayer(p);
    writeln(f.dice);
    foreach(i; 0..6){
        f.roll(Roll([i]));
        writeln(f.dice);
    }


    void setRoll(int[] dice){
        foreach(i, d; dice){
            f.dice[i].held = false;
            f.dice[i].showing = d;
        }
    }

    struct RollResult{
        int[6] dice;
        LabeledScore expected;
    }
    
    auto rolls = [
                  RollResult([1,2,3,4,5,6], LabeledScore(3000, "straight")),
                  RollResult([2,3,6,5,4,1], LabeledScore(3000, "straight")),
                  RollResult([2,2,2,2,3,2], LabeledScore(600, "five 2's")),
                  RollResult([2,3,2,3,2,3], LabeledScore(2500, "two triplets")),
                  RollResult([2,2,2,3,4,4], LabeledScore(200, "three 2's")),
                  RollResult([2,2,2,2,3,3], LabeledScore(1500, "three doublets")),
                  RollResult([2,2,3,3,4,4], LabeledScore(1500, "three doublets")),
                  RollResult([2,2,2,2,3,4], LabeledScore(400, "four 2's"))
                  ];
    foreach(roll; rolls){
        setRoll(roll.dice);
        writeln("f.scoreRoll: ", f.scoreRoll, " expected: ", roll.expected);
        assert(f.scoreRoll == roll.expected);
    }
}
