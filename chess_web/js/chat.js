/**
 * chat.js — 聊天功能
 */

export function addChatMessage(text, type) {
  var html
  if (type === 'system') {
    html = '<li class="chat-msg" style="justify-content:center;font-style:italic;color:#adb5bd;font-size:12px">' + text + '</li>'
  } else {
    var cls = type === 'white' ? 'msg-user-white' : 'msg-user-black'
    html = '<li class="chat-msg"><span class="' + cls + '"></span><span class="msg-content">' + $('<span>').text(text).html() + '</span></li>'
  }
  $('#chat-messages').append(html)
  var chat = $('#chat-messages')[0]
  if (chat) chat.scrollTop = chat.scrollHeight
}

function sendChat() {
  var $input = $('#chat-input')
  var text = $input.val().trim()
  if (!text) return
  addChatMessage(text, 'white')
  $input.val('')
}

export function initChat() {
  $('#chat-send').on('click', sendChat)
  $('#chat-input').on('keydown', function(e) {
    if (e.key === 'Enter') sendChat()
  })
}
