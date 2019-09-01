pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- utils

function ternary(cond, x, y)
  if (cond) return x
  return y
end

function sort(tbl, comp)
  -- insertion sort
  if comp == nil
  then
    comp = function(x, y)
      return x > y
    end
  end
  for i=1,#tbl
  do
    local j = i
    while j > 1 and 
          comp(tbl[j-1], tbl[j])
    do
      tbl[j],tbl[j-1] = tbl[j-1],tbl[j]
      j = j - 1
    end
  end
end

-- math helpers

-- sin but -0.5 to 0.5
function nsin(t)
  return sin(t) - 0.5
end

function sign(x)
  return ternary(x < 0, -1, 1)
end

function clamp(x, xmin, xmax)
  if (x < xmin) return xmin
  if (x > xmax) return xmax
  return x
end

function in_range(x, xmin, xmax)
  return x >= xmin and x <= xmax
end
  
function rnd_in(tbl)
  return tbl[flr(rnd(#tbl)) + 1]
end

-- push |x| towards target |t|
-- by distance |d|
function push_towards(x, t, d)
  d = abs(d)
  if (abs(t - x) <= d) return t
  if (t < x) return x - d
  return x + d
end

-- class helpers (thanks dan!)

function class(superclass)
  local myclass = {}
  myclass.__index = myclass
  myclass._init = function() end

  local mt = {}
  mt.__call = function(
      self, ...)
    local instance = (
        setmetatable({}, self))
    instance:_init(...)
    return instance
  end

  if superclass then
    mt.__index = superclass
    mt.__metatable = superclass
  end

  return setmetatable(myclass,
                      mt)
end

-- vector

vec = class()

function vec:_init(x, y)
  if type(x) == "table"
  then
    -- copy ctor
    self.x=x.x
    self.y=x.y
  else
    -- value ctor
    self.x=x or 0
    self.y=y or 0
  end
end

-- makes a binary operator for
-- the vector that can take
-- either two vectors or
-- a vector and a number
function _vec_binary_op(op)
  return function(v1, v2)
    if type(v1) == "table" and
       type(v2) == "table"
    then
      -- two vectors
      return vec(op(v1.x, v2.x),
                 op(v1.y, v2.y))
    end

    -- one of the arguments
    -- should be numeric
    if type(v1) == "table"
    then
      -- v2 is numeric
      return vec(op(v1.x, v2),
                 op(v1.y, v2))
    end
  
    -- v1 is numeric
    -- preserving the order of 
    -- operations is important
    return vec(op(v1, v2.x),
               op(v1, v2.y))
  end
end

vec.__add = _vec_binary_op(
    function(x,y) return x+y end)

vec.__sub = _vec_binary_op(
    function(x,y) return x-y end)

vec.__mul = _vec_binary_op(
    function(x,y) return x*y end)

vec.__div = _vec_binary_op(
    function(x,y) return x/y end)

vec.__pow = _vec_binary_op(
    function(x,y) return x^y end)

vec.__unm =
    function(v)
      return vec(-v.x, -v.y)
    end

vec.__eq =
    function(v1, v2)
      return v1.x == v2.x and
             v1.y == v2.y
    end

function vec:mag()
  return sqrt(self:sqr_mag())
end

function vec:sqr_mag()
  return self.x * self.x +
         self.y * self.y
end

function vec:normalized()
  local mag = self:mag()
  if (mag == 0) return vec()
  return self / self:mag()
end

function vec:min(v)
  return vec(
      min(self.x, v.x),
      min(self.y, v.y))
end

function vec:max(v)
  return vec(
      max(self.x, v.x),
      max(self.y, v.y))
end

function vec:clamp(vmin, vmax)
  return vec(
      clamp(self.x, vmin.x,
            vmax.x),
      clamp(self.y, vmin.y,
            vmax.y))
end

-- push a vector towards target
-- |t| by delta |d|
function vec:push_towards(t, d)
  if type(d) == "table"
  then
    -- separate x and y deltas
    return vec(
        push_towards(self.x,
                     t.x, d.x),
        push_towards(self.y,
                     t.y, d.y))
  end
  
  local direc = t - self
  local dvec =
      direc:normalized() * d
  
  return vec(
      push_towards(self.x, t.x,
                   dvec.x),
      push_towards(self.y, t.y,
                   dvec.y))
end

-- table helpers

function addall(xs, ys)
  for y in all(ys)
  do
    add(xs, y)
  end
end

-- random helpers

function rndbool()
  return rnd(100) >= 50
end

-- hitbox

hbox = class()

function hbox:_init(pos, size)
  self.pos = vec(pos)
  self.size = vec(size)
end

function hbox:contains(v)
  return in_range(
      v.x,
      self.pos.x,
      self.pos.x + self.size.x
  ) and in_range(
      v.y,
      self.pos.y,
      self.pos.y + self.size.y)
end

function hbox:intersects(other)
  -- assumes pos is top-left
  local top_left1 = self.pos
  local btm_right1 = top_left1 + self.size
  local top_left2 = other.pos
  local btm_right2 = top_left2 + other.size
  
  return (
    top_left1.x < btm_right2.x and
    top_left1.y < btm_right2.y and
    btm_right1.x > top_left2.x and
    btm_right1.y > top_left2.y)
end

-- animation

anim = class()

function anim:_init(
    start_sprid, end_sprid,
    is_loop, duration)
  duration = duration or 1
  is_loop = ternary(
    is_loop != nil,
    is_loop, true)

  self.start_sprid = start_sprid
  self.end_sprid = end_sprid
  self.is_loop = is_loop
  self.duration = duration

  self:reset()
end

function anim_single(
    sprid, ...)
  return anim(
      sprid, sprid,
      --[[is_loop=]]false,
      ...)
end

function anim:reset()
  self.sprid = self.start_sprid
  self.ticks = 0
  self.done = false
end

function anim:update()
  self.ticks = min(
      self.ticks + 1,
      self.duration)
  
  local done_frame = (
      self.ticks ==
      self.duration)
  local done_last_frame = (
      self.sprid ==
      self.end_sprid) and
      done_frame

  if done_last_frame and
     not self.is_loop
  then
    self.done = true
    return
  end
  
  if (not done_frame) return
  
  self.ticks = 0
  if done_last_frame
  then
    self.sprid = self.start_sprid
  else
    self.sprid += 1
  end
end

function anim:draw(pos, flip_x)
  spr(self.sprid, pos.x,
      pos.y, 1, 1, flip_x)
end

anim_chain = class()

function anim_chain:_init(
    anims, is_loop)
  self.anims = anims
  self.is_loop = is_loop
  self:reset()

  self.duration = 0
  for anim in all(anims) do
    self.duration += anim.duration
  end
end

function anim_chain:reset()
  self.current = 1
  self.done = false
  self.sprid = self.anims[1].sprid
  for anim in all(self.anims) do
    anim:reset()
  end
end

function anim_chain:anim()
  return self.anims[
      self.current]
end

function anim_chain:update()
  local anim = self:anim()
  anim:update()
  self.sprid = anim.sprid
    
  if (not anim.done) return
  
  -- we just finished an anim
  local done_last_anim = (
      self.current ==
      #self.anims)
  if not done_last_anim
  then
    -- next anim in chain
    self.current += 1
    self:anim():reset()
  elseif self.is_loop
  then
    -- loop chain
    self.current = 1
    self:anim():reset()
  else
    -- no loop
    self.done = true
  end
end

function anim_chain:draw(
    pos, flip_x)
  self:anim():draw(pos, flip_x)
end

-- button helpers

local prev_btn = {
  false,
  false,
  false,
  false,
  false,
  false,
}

-- like btnp, but without
-- keyboard repeating
function btnjp(i)
  -- todo: add support for more
  -- than one player
  return btn(i) and
         not prev_btn[i+1]
end

-- call this at the end of
-- every update
function update_prev_btn()
  prev_btn[1] = btn(0)
  prev_btn[2] = btn(1)
  prev_btn[3] = btn(2)
  prev_btn[4] = btn(3)
  prev_btn[5] = btn(4)
  prev_btn[6] = btn(5)
end

-- life utils

function filter_alive(xs)
  alive = {}
  for x in all(xs)
  do
    if x.life > 0 then
      add(alive, x)
    end
  end
  return alive 
end

-- timers

local timer = class()

function timer:_init(
  life, f1, f2)
 self.start = life
 self.life = life

 if f2 != nil
 then
  self.on_update = f1
  self.on_done = f2
 else
  self.on_done = f1
 end
end

function timer:ratio_complete()
 return (
   self.start - self.life
 ) / self.start
end

function timer:done()
 return self == nil or
   self.life == 0
end

function timer:update()
 local prevlife = self.life
 self.life = max(0, self.life-1)
 if self:done() and
    prevlife > 0 and
    self.on_done != nil
 then
  self.on_done()
 elseif self.life > 0 and
        self.on_update != nil
 then
  self.on_update(
    self:ratio_complete())
 end
end

-- world state

local state = class()

function state:_init()
 self._groups = {}
end

function state:_group(group)
 if not self._groups[group]
 then
  self._groups[group] = {}
 end

 return self._groups[group]
end

function state:add(group, x)
 add(self:_group(group), x)
 return x
end

function state:addtimer(...)
 return self:add("timers",
                 timer(...))
end

function state:updateall(group)
 local xs = self:_group(group)
 for x in all(xs)
 do
  x:update(self)
 end
 
 self._groups[group] =
   filter_alive(xs)
end

function state:drawall(group)
 for x in all(self:_group(group))
 do
  x:draw()
 end
end
-->8
-- bullet

local bullet = class()

function bullet:_init(
  anim, pos, vel, props)
 self.anim = anim
 self.pos = vec(pos)
 self.vel = vec(vel)
 
 props = props or {}
 self.life = props.life or 200
 self.is_enemy =
   props.is_enemy or false
end

function bullet:update()
 self.life = max(0,self.life-1)
 self.pos += self.vel
end

function bullet:draw()
 self.anim:draw(self.pos,
                self.vel.x >= 0)
end

-- player

local player = class()

local idle = 0
local walk = 1

function player:_init(pos)
 self.pos = vec(pos)
 self.vel = vec()
 self.size = vec(5, 6)
 self.idle_anim = anim_single(1)
 self.walk_anim = anim_single(1)
 self.anim = self.idle_anim
 self.walking = false
 self.jumping = true
 self.left = false
end

function player:update(s)

 local prevwalking =
   self.walking
 local speed = 1 
 self.vel.x = 0
 if btn(⬅️) then
  self.left = true
  self.walking = true
  self.vel.x = -speed
 elseif btn(➡️) then
  self.left = false
  self.walking = true
  self.vel.x = speed
 else
  self.walking = false
 end
 
 if not self.jumping and
    btnjp(🅾️)
 then
  self.jumping = true
  self.vel.y = -1.5
 end
 
 if timer.done(self.tfire) and
    btn(❎)
 then
  local offset = ternary(
    self.left,
    vec(-4, 0), vec(4, 0))
  local vel = ternary(
    self.left,
    vec(-2, 0), vec(2, 0))
  s:add("bullets",
    bullet(
      anim_single(4),
      self.pos + offset,
      vel))
  self.tfire = s:addtimer(10)      
 end
 
 if self.walking then
  self.anim = self.walk_anim
 else
  self.anim = self.idle_anim
 end
 
 if self.walking != prevwalking
 then
  self.anim:reset()
 end
 
 local gravity = vec(0, 0.1)
 self.vel += gravity
 self.pos += self.vel
 if self.pos.y > 104
 then
  self.jumping = false
  self.pos.y = 104
 end
 
 self.anim:update()
end

function player:draw()
 self.anim:draw(self.pos,
                self.left)
end
-->8
-- game

local s = state()

function _init()
 s.player = player(vec(20, 20))
end

function _update60()
 s.player:update(s)

 s:updateall("bullets")
 s:updateall("timers")
end

function _draw()
 cls()
 
 rectfill(0, 0, 128, 110, 1)

 s.player:draw()
 s:drawall("bullets")
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700070000700700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000070808707777777077777770000888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000070000707000007070000070088888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077777707070077070700770000888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000070007007000007070000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777777077777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
