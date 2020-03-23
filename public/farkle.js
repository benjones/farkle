
const svgNS = "http://www.w3.org/2000/svg";

let ws; //global for debuggin purposes

const unselectedBG = "red";
const pipColor = "black";

window.onload = function(){

    ws = new WebSocket("ws://" + location.host + "/ws");
    ws.onmessage = function(m){ console.log(m); };
    

    let dice = document.getElementsByClassName("die");

    for(let i = 0; i < dice.length; i++){
        initDie(dice[i]);
        updateDie(dice[i], i +1);
    }
    console.log(dice);
    
    
}



function initDie(die){

    let svgRect = die.getBoundingClientRect();

    let bg = document.createElementNS(svgNS, "rect");
    bg.setAttribute("width", svgRect.width);
    bg.setAttribute("height", svgRect.height);
    bg.setAttribute("rx", svgRect.width*.1);
    bg.setAttribute("fill", unselectedBG);

    die.appendChild(bg);
}


function updateDie(die, showing){

    const allPips = [
        [ [0.5, 0.5] ],
        [ [0.25, 0.25], [0.75, 0.75]],
        [ [0.25, 0.25], [0.5, 0.5], [0.75, 0.75] ],
        [ [0.25, 0.25], [0.25, 0.75], [0.75, 0.25], [0.75, 0.75] ],
        [ [0.25, 0.25], [0.25, 0.75], [0.75, 0.25], [0.75, 0.75], [0.5, 0.5] ],
        [ [0.25, 0.25], [0.25, 0.5], [0.25, 0.75], [0.75, 0.25], [0.75, 0.5], [0.75, 0.75] ],
    ];

    //delete old pips

    let oldPips = die.getElementsByClassName("pip");
    for(let pip of oldPips){
        pip.remove();
    }

    if(showing < 1 || showing > 6) return;
    
    for( let coord of allPips[showing -1]){
        let svgRect = die.getBoundingClientRect();
        let sw = svgRect.width;
        let sh = svgRect.height;
        
        let pip = document.createElementNS(svgNS, "circle");
        pip.setAttribute("cx", coord[0]*sw);
        pip.setAttribute("cy", coord[1]*sh);
        pip.setAttribute("r", 0.08*sw);
        pip.setAttribute("fill", pipColor);
        
        die.appendChild(pip);
        
    }
    
    
}
