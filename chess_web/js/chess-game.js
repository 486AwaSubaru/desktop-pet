/**
 * chess-game.js — 棋局逻辑
 *
 * 导出 game 实例和操作棋局的纯函数。
 */

import { Chess } from '../lib/chess.js/dist/esm/chess.js'

export var game = new Chess()
export var $status = $('#status')

// ========== 走棋 ==========

export function tryMove(source, target, promotion) {
  var move
  try {
    move = game.move({ from: source, to: target, promotion: promotion })
  } catch (e) {
    console.warn('move error:', e)
    return 'snapback'
  }
  if (move === null) return 'snapback'
  updateStatus()
  renderPgn()
}

// ========== 棋谱渲染 ==========

export function renderPgn() {
  var raw = game.pgn()
  if (!raw) {
    $('#pgn-list').html('<span style="color:#adb5bd;grid-column:1/-1;text-align:center;padding:20px 0">等待对局开始…</span>')
    return
  }

  raw = raw.replace(/\[.*?\]\s*/g, '')
           .replace(/\s*(1-0|0-1|1\/2-1\/2|\*)\s*$/, '')

  var parts = raw.split(/\d+\.\s*/).filter(Boolean)
  var html = ''
  for (var i = 0; i < parts.length; i++) {
    var tokens = parts[i].trim().split(/\s+/)
    var w = tokens[0] || ''
    var b = tokens[1] || ''
    html += '<span class="move-num">' + (i + 1) + '.</span>'
    html += '<span class="move-text">' + w + '</span>'
    html += '<span class="move-text">' + (b || '') + '</span>'
  }

  $('#pgn-list').html(html)

  var section = $('.pgn-section')[0]
  if (section) section.scrollTop = section.scrollHeight
}

// ========== 状态更新 ==========

export function updateStatus() {
  var status = ''
  var moveColor = game.turn() === 'b' ? 'Black' : 'White'

  if (game.isCheckmate()) {
    status = 'Game over, ' + moveColor + ' is in checkmate.'
  } else if (game.isDraw()) {
    status = 'Game over, drawn position'
  } else {
    status = moveColor + ' to move'
    if (game.isCheck()) {
      status += ', ' + moveColor + ' is in check'
    }
  }

  $status.html(status)
  $('#status-text').text(status)
}
