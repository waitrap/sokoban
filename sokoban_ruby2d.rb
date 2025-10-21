#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# 倉庫番ゲーム - Ruby2D版
# インストール: gem install ruby2d
# 実行: ruby sokoban_ruby2d.rb

require 'ruby2d'

# 設定
TILE_SIZE = 64
WINDOW_WIDTH = 640
WINDOW_HEIGHT = 520

# レベルマップ
MAP = [
  "########",
  "#  . . #",
  "# $    #",
  "#      #",
  "#  $ @ #",
  "#      #",
  "########"
]

# ゲーム状態
@map = MAP.map { |row| row.chars }
@original = @map.map(&:dup)
@moves = 0
@history = []
@px = 0
@py = 0
@tiles = []
@game_over = false

# 目標位置の順序を記録し、異なる目標に置かれた箱に異なる画像を表示するため
@target_positions = []
@original.each_with_index do |row, y|
  row.each_with_index do |cell, x|
    @target_positions << [x, y] if cell == '.'
  end
end

# オフセットを計算
@ox = (WINDOW_WIDTH - @map[0].length * TILE_SIZE) / 2
@oy = (WINDOW_HEIGHT - @map.length * TILE_SIZE) / 2 + 20

# ウィンドウ設定
set title: "倉庫番 - Ruby2D"
set width: WINDOW_WIDTH
set height: WINDOW_HEIGHT
set background: '#2c3e50'

# プレイヤーの位置を検索
def find_player
  @map.each_with_index do |row, y|
    row.each_with_index do |cell, x|
      if cell == '@' || cell == '+'
        @px, @py = x, y
        return
      end
    end
  end
end

# 全ての描画要素を削除
def clear_tiles
  @tiles.each(&:remove)
  @tiles.clear
end

# マップを描画
def render_map
  clear_tiles
  
  # 描画
  @map.each_with_index do |row, y|
    row.each_with_index do |cell, x|
      sx = @ox + x * TILE_SIZE
      sy = @oy + y * TILE_SIZE
      
      if cell == '#'
        # 壁として指定した画像を使用（プロジェクトの assets/wall.png に置く）
        begin
          img = Image.new(
            'assets/wall.png',
            x: sx + 2,
            y: sy + 2,
            width: TILE_SIZE - 4,
            height: TILE_SIZE - 4
          )
          @tiles << img
        rescue StandardError
          # 画像が見つからない場合は四角で代用
          tile = Square.new(
            x: sx + 2,
            y: sy + 2,
            size: TILE_SIZE - 4,
            color: '#555555'
          )
          @tiles << tile
        end
        next
      end
      
      # 基本の地面
      tile = Square.new(
        x: sx + 2,
        y: sy + 2,
        size: TILE_SIZE - 4,
        color: '#ecf0f1'
      )
      @tiles << tile

      # 目標位置には目標画像を表示（. / + / *）
      if cell == '.' || cell == '+' || cell == '*'
        begin
          timg = Image.new(
            'assets/target.png',
            x: sx + 2,
            y: sy + 2,
            width: TILE_SIZE - 4,
            height: TILE_SIZE - 4
          )
          @tiles << timg
        rescue StandardError
          circle = Circle.new(
            x: sx + TILE_SIZE/2,
            y: sy + TILE_SIZE/2,
            radius: 8,
            color: '#f39c12'
          )
          @tiles << circle
        end
      end

      # 通常の箱($) は箱の画像を使用
      if cell == '$'
        begin
          bimg = Image.new(
            'assets/box.png',
            x: sx + 2,
            y: sy + 2,
            width: TILE_SIZE - 4,
            height: TILE_SIZE - 4
          )
          @tiles << bimg
        rescue StandardError
          box_tile = Square.new(
            x: sx + 2,
            y: sy + 2,
            size: TILE_SIZE - 4,
            color: '#e67e22'
          )
          @tiles << box_tile
        end
      end

      # 目標上の箱(*) は対応する目標用の箱画像を表示（目標の順序に基づく）
      if cell == '*'
        begin
          idx = @target_positions.index([x, y])
          box_on_target_path = if idx
                                 "assets/box_on_target#{idx + 1}.png"
                               else
                                 'assets/box_on_target.png'
                               end
          bimg_t = Image.new(
            box_on_target_path,
            x: sx + 2,
            y: sy + 2,
            width: TILE_SIZE - 4,
            height: TILE_SIZE - 4
          )
          @tiles << bimg_t
        rescue StandardError
          # 画像がない場合は緑の四角で代用
          box_tile = Square.new(
            x: sx + 2,
            y: sy + 2,
            size: TILE_SIZE - 4,
            color: '#27ae60'
          )
          @tiles << box_tile
        end
      end

      # プレイヤーが通常のマス(@) または目標マス(+) にいる場合
      if cell == '@' || cell == '+'
        begin
          pimg = Image.new(
            'assets/player.png',
            x: sx + 2,
            y: sy + 2,
            width: TILE_SIZE - 4,
            height: TILE_SIZE - 4
          )
          @tiles << pimg
        rescue StandardError
          # 画像がない場合は青い四角で代用（元の実装との互換性のため）
          player_tile = Square.new(
            x: sx + 2,
            y: sy + 2,
            size: TILE_SIZE - 4,
            color: '#3498db'
          )
          @tiles << player_tile
        end
      end
    end
  end
end

# 移動
def move_player(dx, dy)
  return if @game_over
  
  nx = @px + dx
  ny = @py + dy
  
  return if @map[ny][nx] == '#'
  
  box_info = nil
  
  # 箱を押す
  if @map[ny][nx] == '$' || @map[ny][nx] == '*'
    bx = nx + dx
    by = ny + dy
    
    return if @map[by][bx] == '#'
    return if @map[by][bx] == '$' || @map[by][bx] == '*'
    
    box_info = [nx, ny, @map[ny][nx] == '*']
    @map[by][bx] = (@original[by][bx] == '.') ? '*' : '$'
  end
  
  # 履歴を保存
  @history << [@px, @py, box_info]
  
  # プレイヤーを移動
  @map[@py][@px] = (@original[@py][@px] == '.') ? '.' : ' '
  @map[ny][nx] = (@original[ny][nx] == '.') ? '+' : '@'
  @px, @py = nx, ny
  @moves += 1
  
  render_map
  check_win
end

# 元に戻す
def undo_move
  return if @history.empty?
  
  px, py, box = @history.pop
  
  # 箱を復元
  if box
    bx, by, was_target = box
    @map[@py][@px] = (@original[@py][@px] == '.') ? '.' : ' '
    @map[by][bx] = was_target ? '*' : '$'
  else
    @map[@py][@px] = (@original[@py][@px] == '.') ? '.' : ' '
  end
  
  # プレイヤーを復元
  @map[py][px] = (@original[py][px] == '.') ? '+' : '@'
  @px, @py = px, py
  @moves -= 1
  
  render_map
  @game_over = false
end

# リセット
def reset_game
  @map = MAP.map { |row| row.chars }
  @original = @map.map(&:dup)
  @moves = 0
  @history.clear
  @game_over = false
  find_player
  render_map
end

# クリア判定
def check_win
  @map.each do |row|
    row.each do |cell|
      return false if cell == '$' || cell == '.'
    end
  end
  @game_over = true
  true
end

# テキスト表示を作成
@move_text = Text.new(
  "移動: 0",
  x: 20,
  y: 10,
  size: 24,
  color: 'white'
)

@tips_text = Text.new(
  "WASD/矢印キー:移動  U:元に戻す  R:リセット  ESC:終了",
  x: 20,
  y: WINDOW_HEIGHT - 20,  # 下に10ピクセル移動して上と重ならないようにする（元は -35）
  size: 18,
  color: 'white'
)

@win_text = Text.new(
  "10周年おめでとう",
  x: WINDOW_WIDTH/2 - 200,
  y: WINDOW_HEIGHT/2 - 20,
  size: 60,
  color: '#27ae60',
  z: 10
)
@win_text.remove

# 移動回数表示を更新
update do
  @move_text.text = "移動: #{@moves}"
  
  if @game_over
    @win_text.add
  else
    @win_text.remove
  end
end

# キーボード操作
on :key_down do |event|
  case event.key
  when 'w', 'up'
    move_player(0, -1)
  when 's', 'down'
    move_player(0, 1)
  when 'a', 'left'
    move_player(-1, 0)
  when 'd', 'right'
    move_player(1, 0)
  when 'u', 'z'
    undo_move
  when 'r'
    reset_game
  when 'escape'
    close
  end
end

# 初期化
find_player
render_map

# ゲーム開始
show