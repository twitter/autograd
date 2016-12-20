-- util
local util = require 'autograd.util'
local d = require 'autograd'

return function(opt, params)
   -- options:
   opt = opt or {}
   local inputFeatures = opt.inputFeatures or 10
   local hiddenFeatures = opt.hiddenFeatures or 100
   local l = opt.lambda or 0.9
   local e = opt.eta or 0.5
   local S = opt.S or 1
   local outputType = opt.outputType or 'last' -- 'last' or 'all'
   local relu = d.nn.ReLU()

   -- container:
   params = params or {}

   -- parameters:
   local p = {
      W = torch.zeros(inputFeatures+hiddenFeatures, hiddenFeatures),
      b = torch.zeros(1, hiddenFeatures),
   }
   table.insert(params, p)

   -- function:
   local f = function(params, x, prevState)
      -- dims:
      local p = params[1] or params
      if torch.nDimension(x) == 2 then
         x = torch.view(x, 1, torch.size(x, 1), torch.size(x, 2))
      end
      local batch = torch.size(x, 1)
      local steps = torch.size(x, 2)

      -- hiddens:
      prevState = prevState or {}

      -- prev h
      local hp = prevState.h or torch.zero(x.new(batch, hiddenFeatures))

      -- fast weights
      local A = prevState.A or torch.zero(x.new(hiddenFeatures, hiddenFeatures))

      -- fast weights update
      A = l * A + e * (torch.t(hp) * hp)

      local hs = {}
      -- go over time:
      for t = 1, steps do
         -- xt
         local xt = torch.select(x, 2, t)

         -- prev h
         hp = hs[t-1] or hp

         -- pack all dot products:
         local dot = torch.cat(xt, hp, 2) * p.W
                   + torch.expand(p.b, batch, hiddenFeatures)

         hs[t] = torch.zero(x.new(batch, hiddenFeatures))
         for s = 0, S do
            -- next h:
            hs[t] = relu(dot + hs[t] * A)
         end
      end


      -- save state
      local newState = {h=hs[#hs]}

      -- output:
      if outputType == 'last' then
         -- return last hidden code:
         return hs[#hs], newState
      else
         -- return all:
         for i in ipairs(hs) do
            hs[i] = torch.view(hs[i], batch,1,hiddenFeatures)
         end
         return x.cat(hs, 2), newState
      end
   end

   -- layers
   return f, params
end

