/* =========================
   NOTIFY SYSTEM
========================= */

let queue = []
let isShowing = false

window.addEventListener("message", function(event){

    if(event.data.type === "show"){
        queue.push(event.data)
        processQueue()
    }

    /* HIDE QB NOTIFICATIONS */
    if(event.data.action === "hideQB"){
        const qb = document.querySelector(".notify-container")
        if(qb){
            qb.style.display = "none"
        }
    }
})

function processQueue(){
    if(isShowing || queue.length === 0) return

    isShowing = true

    const data = queue.shift()
    const duration = data.duration || 4000

    const container = document.getElementById("notify-container")

    const notify = document.createElement("div")
    notify.classList.add("notify")

    notify.innerHTML = `
        <div class="row">
            <img src="mechanic.png" class="logo">
            <div class="text">${data.text}</div>
        </div>
        <div class="progress">
            <div class="progressbar"></div>
        </div>
    `

    container.appendChild(notify)

    const bar = notify.querySelector(".progressbar")

    setTimeout(()=>{
        notify.classList.add("show")
    },50)

    /* Progressbar */
    bar.style.width = "100%"
    bar.style.transition = "none"

    setTimeout(()=>{
        bar.style.transition = `width ${duration}ms linear`
        bar.style.width = "0%"
    },50)

    /* Remove */
    setTimeout(()=>{
        notify.style.opacity = "0"

        setTimeout(()=>{
            notify.remove()
            isShowing = false
            processQueue()
        },300)

    }, duration)
}