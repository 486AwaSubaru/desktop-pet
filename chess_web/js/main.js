/**
 * main.js — 入口模块
 *
 * 导入各子模块，初始化并绑定 UI 事件。
 */

import { game, tryMove, updateStatus, renderPgn } from './chess-game.js'
import { board, pendingPromotion, initBoard } from './board.js'
import { addChatMessage, initChat } from './chat.js'

// ========== 初始化棋盘 ==========

initBoard()

// ========== 右侧面板高度与棋盘对齐 ==========

function syncPanelHeight() {
  var h = $('#myBoard').height()
  $('.right-panel').height(h)
}
syncPanelHeight()
$(window).on('resize', syncPanelHeight)

// ========== 按钮事件 ==========

$('#btn-restart').on('click', function() {
  game.reset()
  board.start()
  updateStatus()
  renderPgn()
  addChatMessage('Game restarted', 'system')
})

$('#btn-flip').on('click', function() {
  board.orientation('flip')
  addChatMessage('Board flipped', 'system')
})

$('#btn-draw').on('click', function() {
  addChatMessage('Draw offered', 'system')
})

$('#btn-resign').on('click', function() {
  addChatMessage('Game resigned', 'system')
})

// ========== 初始化聊天 ==========

initChat()

// ========== 初始渲染 ==========

updateStatus()
renderPgn()
