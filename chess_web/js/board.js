/**
 * board.js — 棋盘渲染与交互
 *
 * 导出 board 对象、pendingPromotion、初始化函数及相关回调。
 */

import { game, tryMove, updateStatus, renderPgn } from './chess-game.js'

export var board = null
export var pendingPromotion = null

// ========== 棋盘回调 ==========

function onDragStart(source, piece, position, orientation) {
  if (game.isGameOver()) return false
  if ((game.turn() === 'w' && piece.search(/^b/) !== -1) ||
      (game.turn() === 'b' && piece.search(/^w/) !== -1)) {
    return false
  }
}

function onDrop(source, target, piece) {
  if (piece && piece[1] === 'P') {
    var targetRank = target[1]
    if ((piece[0] === 'w' && targetRank === '8') ||
        (piece[0] === 'b' && targetRank === '1')) {

      var testMove
      try {
        testMove = game.move({ from: source, to: target, promotion: 'q' })
      } catch (e) {
        return 'snapback'
      }
      if (testMove === null) return 'snapback'

      game.undo()
      pendingPromotion = { source: source, target: target, color: piece[0] }
      return undefined
    }
  }
  return tryMove(source, target, 'q')
}

function onSnapEnd() {
  if (pendingPromotion) {
    showPromotionDialog(pendingPromotion.color)
    return
  }
  board.position(game.fen())
}

// ========== 兵升变 ==========

function promoteTo(pieceType) {
  if (!pendingPromotion) return
  var p = pendingPromotion
  pendingPromotion = null
  hidePromotionDialog()
  tryMove(p.source, p.target, pieceType)
  board.position(game.fen())
}

function showPromotionDialog(color) {
  var pieces = ['q', 'r', 'b', 'n']
  var names = { q: 'Q', r: 'R', b: 'B', n: 'N' }
  var html = pieces.map(function(p) {
    var code = color + names[p]
    return '<img src="lib/chessboard/img/chesspieces/wikipedia/' + code + '.png" data-piece="' + p + '" title="' + names[p] + '">'
  }).join('')
  $('#promo-dialog').html(html)
  $('#promo-overlay').addClass('show')
}

function hidePromotionDialog() {
  $('#promo-overlay').removeClass('show')
}

$(document).on('click', '#promo-dialog img', function() {
  promoteTo($(this).data('piece'))
})

// ========== 初始化 ==========

export function initBoard() {
  board = Chessboard('myBoard', {
    draggable: true,
    position: 'start',
    pieceTheme: 'lib/chessboard/img/chesspieces/wikipedia/{piece}.png',
    onDragStart: onDragStart,
    onDrop: onDrop,
    onSnapEnd: onSnapEnd
  })
}
