function p(){if("ontouchstart"in window)return;let r=200,v=8,o,n,i=t=>{o=t.pageX,n=t.pageY},e={};$("#topnav.hover").each(function(){let t=$(this).removeClass("hover"),m=()=>t.toggleClass("hover"),a=()=>{Math.sqrt((e.pX-o)*(e.pX-o)+(e.pY-n)*(e.pY-n))<v?(t.off(e.event,i),delete e.timeoutId,e.isActive=!0,m()):(e.pX=o,e.pY=n,e.timeoutId=setTimeout(a,r))},c=function(s){e.timeoutId&&(clearTimeout(e.timeoutId),delete e.timeoutId);let u=e.event="mousemove";if(s.type==="mouseover"){if(e.isActive||s.buttons)return;e.pX=s.pageX,e.pY=s.pageY,t.off(u,i).on(u,i),e.timeoutId=setTimeout(a,r)}else{if(!e.isActive)return;t.off(u,i),e={},m()}};t.on("mouseover",c).on("mouseleave",c)})}export{p as a};
/*!
 * hoverIntent v1.10.0 // 2019.02.25 // jQuery v1.7.0+
 * http://briancherne.github.io/jquery-hoverIntent/
 *
 * You may use hoverIntent under the terms of the MIT license. Basically that
 * means you are free to use hoverIntent as long as this header is left intact.
 * Copyright 2007-2019 Brian Cherne
 */
