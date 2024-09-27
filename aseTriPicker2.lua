local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919
local sqrt3_2 <const> = 0.86602540378444

local defaults <const> = {
    -- Sliders.
    rLevels = 8,
    gLevels = 8,
    bLevels = 8,

    wCanvas = 200,
    hCanvas = 200,

    hue = 0.0,
    sat = 1.0,
    val = 1.0,
    alpha = 1.0,

    red = 1.0,
    green = 0.0,
    blue = 0.0,

    ringInEdge = 0.9,
    angOffsetRadians = 0.5235987755983,
    swatchSize = 16,
    textDisplayLimit = 50,
}

local active <const> = {
    wCanvas = defaults.wCanvas,
    hCanvas = defaults.hCanvas,

    rMax = (1 << defaults.rLevels) - 1.0,
    gMax = (1 << defaults.gLevels) - 1.0,
    bMax = (1 << defaults.bLevels) - 1.0,

    hueFore = defaults.hue,
    satFore = defaults.sat,
    valFore = defaults.val,

    redFore = defaults.red,
    greenFore = defaults.green,
    blueFore = defaults.blue,

    alphaFore = defaults.alpha,

    hueBack = defaults.hue,
    satBack = defaults.sat,
    valBack = defaults.val,

    redBack = defaults.red,
    greenBack = defaults.green,
    blueBack = defaults.blue,

    alphaBack = defaults.alpha,

    isBackActive = false,
    mouseDownRing = false,
    mouseDownTri = false,
}

---@param h number
---@param s number
---@param v number
---@return number r
---@return number g
---@return number b
local function hsvToRgb(h, s, v)
    local h6 <const> = h * 6.0

    local sector <const> = math.floor(h6)
    local tint1 <const> = v * (1.0 - s)
    local tint2 <const> = v * (1.0 - s * (h6 - sector))
    local tint3 <const> = v * (1.0 - s * (1.0 + sector - h6))

    if sector == 0 then
        return v, tint3, tint1
    elseif sector == 1 then
        return tint2, v, tint1
    elseif sector == 2 then
        return tint1, v, tint3
    elseif sector == 3 then
        return tint1, tint2, v
    elseif sector == 4 then
        return tint3, tint1, v
    elseif sector == 5 then
        return v, tint1, tint2
    end

    return 0.0, 0.0, 0.0
end

---@param r number
---@param g number
---@param b number
---@return number h
---@return number s
---@return number v
local function rgbToHsv(r, g, b)
    local gbmx <const> = math.max(g, b)
    local gbmn <const> = math.min(g, b)
    local mx <const> = math.max(r, gbmx)

    if mx <= 0.0 then return 0.0, 0.0, 0.0 end

    local mn <const> = math.min(r, gbmn)
    local chroma <const> = mx - mn

    if chroma <= 0.0 then return 0.0, 0.0, mx end

    local hue = 0.0
    if r == mx then
        hue = (g - b) / chroma
        if g < b then hue = hue + 6.0 end
    elseif g == mx then
        hue = 2.0 + (b - r) / chroma
    elseif b == mx then
        hue = 4.0 + (r - g) / chroma
    end

    return hue / 6.0, chroma / mx, mx
end

local function updateActiveFromLevels()
    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    local r01Fore <const> = active.redFore
    local g01Fore <const> = active.greenFore
    local b01Fore <const> = active.blueFore

    local rqFore <const> = math.floor(r01Fore * rMax + 0.5) / rMax
    local gqFore <const> = math.floor(g01Fore * gMax + 0.5) / gMax
    local bqFore <const> = math.floor(b01Fore * bMax + 0.5) / bMax

    active.redFore = rqFore
    active.greenFore = gqFore
    active.blueFore = bqFore

    local hqFore <const>,
    sqFore <const>,
    vqFore <const> = rgbToHsv(rqFore, gqFore, bqFore)

    if vqFore > 0.0 then
        if sqFore > 0.0 then
            active.hueFore = hqFore
        end
        active.satFore = sqFore
    end
    active.valFore = vqFore

    local r01Back <const> = active.redBack
    local g01Back <const> = active.greenBack
    local b01Back <const> = active.blueBack

    local rqBack <const> = math.floor(r01Back * rMax + 0.5) / rMax
    local gqBack <const> = math.floor(g01Back * gMax + 0.5) / gMax
    local bqBack <const> = math.floor(b01Back * bMax + 0.5) / bMax

    active.redBack = rqBack
    active.greenBack = gqBack
    active.blueBack = bqBack

    local hqBack <const>,
    sqBack <const>,
    vqBack <const> = rgbToHsv(rqBack, gqBack, bqBack)

    if vqBack > 0.0 then
        if sqBack > 0.0 then
            active.hueBack = hqBack
        end
        active.satBack = sqBack
    end
    active.valBack = vqBack
end

---@param r8 integer
---@param g8 integer
---@param b8 integer
---@param t8 integer
---@param isBack boolean
local function updateActiveFromRgba8(r8, g8, b8, t8, isBack)
    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    local rq <const> = math.floor((r8 / 255.0) * rMax + 0.5) / rMax
    local gq <const> = math.floor((g8 / 255.0) * gMax + 0.5) / gMax
    local bq <const> = math.floor((b8 / 255.0) * bMax + 0.5) / bMax

    local hueQuantized <const>,
    satQuantized <const>,
    valQuantized <const> = rgbToHsv(rq, gq, bq)

    if isBack then
        if valQuantized > 0.0 then
            if satQuantized > 0.0 then
                active.hueBack = hueQuantized
            end
            active.satBack = satQuantized
        end
        active.valBack = valQuantized

        active.redBack = rq
        active.greenBack = gq
        active.blueBack = bq

        active.alphaBack = t8 / 255.0
    else
        if valQuantized > 0.0 then
            if satQuantized > 0.0 then
                active.hueFore = hueQuantized
            end
            active.satFore = satQuantized
        end
        active.valFore = valQuantized

        active.redFore = rq
        active.greenFore = gq
        active.blueFore = bq

        active.alphaFore = t8 / 255.0
    end
end

---@param event { context: GraphicsContext }
local function onPaint(event)
    local angOffsetRadians <const> = defaults.angOffsetRadians
    local ringInEdge <const> = defaults.ringInEdge
    local sqRie <const> = ringInEdge * ringInEdge

    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local rCanvas <const> = (shortEdge - 1.0) * 0.5
    local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

    -- local rMax <const> = active.rMax
    -- local gMax <const> = active.gMax
    -- local bMax <const> = active.bMax

    -- local rRatio <const> = 255.0 / rMax
    -- local gRatio <const> = 255.0 / gMax
    -- local bRatio <const> = 255.0 / bMax

    local redBack <const> = active.redBack
    local greenBack <const> = active.greenBack
    local blueBack <const> = active.blueBack
    local alphaBack <const> = active.alphaBack

    local redFore <const> = active.redFore
    local greenFore <const> = active.greenFore
    local blueFore <const> = active.blueFore
    local alphaFore <const> = active.alphaFore

    local isBackActive <const> = active.isBackActive
    local hueActive = isBackActive
        and active.hueBack
        or active.hueFore

    -- local hueQuantized <const>,
    -- satQuantized <const>,
    -- valQuantized <const> = rgbToHsv(redActive, greenActive, blueActive)

    -- if valQuantized > 0.0 then
    -- if satQuantized > 0.0 then
    -- hueActive = hueQuantized
    -- end
    -- satActive = satQuantized
    -- end
    -- valActive = valQuantized

    -- Find main point of the triangle.
    local thetaActive <const> = (hueActive * tau) - angOffsetRadians
    local xTri1 <const> = ringInEdge * math.cos(thetaActive)
    local yTri1 <const> = ringInEdge * math.sin(thetaActive)

    -- Find the other two triangle points, 120 degrees away.
    local rt32x <const> = sqrt3_2 * xTri1
    local rt32y <const> = sqrt3_2 * yTri1
    local halfx <const> = -0.5 * xTri1
    local halfy <const> = -0.5 * yTri1

    local xTri2 <const> = halfx - rt32y
    local yTri2 <const> = halfy + rt32x

    local xTri3 <const> = halfx + rt32y
    local yTri3 <const> = halfy - rt32x

    -- For calculation of barycentric coordinates.
    -- Cf. https://codeplea.com/triangular-interpolation
    local yDiff2_3 <const> = yTri2 - yTri3
    local xDiff1_3 <const> = xTri1 - xTri3
    local xDiff3_2 <const> = xTri3 - xTri2
    local yDiff1_3 <const> = yTri1 - yTri3
    local yDiff3_1 <const> = yTri3 - yTri1
    local bwDenom <const> = yDiff2_3 * xDiff1_3 + xDiff3_2 * yDiff1_3
    local bwDnmInv <const> = bwDenom ~= 0.0 and 1.0 / bwDenom or 0.0

    -- Cache method used in while loop.
    local strpack <const> = string.pack
    local floor <const> = math.floor
    local atan <const> = math.atan

    local rBase <const>,
    gBase <const>,
    bBase <const> = hsvToRgb(hueActive, 1.0, 1.0)
    -- local rbQuantized <const> = floor(rBase * rMax + 0.5) / rMax
    -- local gbQuantized <const> = floor(gBase * gMax + 0.5) / gMax
    -- local bbQuantized <const> = floor(bBase * bMax + 0.5) / bMax

    local themeColors <const> = app.theme.color
    local bkgColor <const> = themeColors.window_face
    local packZero <const> = strpack("B B B B",
        bkgColor.red, bkgColor.green, bkgColor.blue, 255)

    ---@type string[]
    local byteStrs <const> = {}
    local lenCanvas <const> = wCanvas * hCanvas
    local i = 0
    while i < lenCanvas do
        local xCanvas <const> = i % wCanvas
        local yCanvas <const> = i // wCanvas

        local xDelta <const> = xCanvas - xCenter
        local yDelta <const> = yCenter - yCanvas

        local xNorm <const> = xDelta * rCanvasInv
        local yNorm <const> = yDelta * rCanvasInv
        local sqMag <const> = xNorm * xNorm + yNorm * yNorm

        local byteStr = packZero
        if sqMag >= sqRie and sqMag <= 1.0 then
            -- Within the rim of the hue circle.
            local angSigned <const> = angOffsetRadians + atan(yNorm, xNorm)
            local hueWheel <const> = (angSigned % tau) * oneTau
            local rWheel <const>,
            gWheel <const>, bWheel <const> = hsvToRgb(hueWheel, 1.0, 1.0)

            byteStr = strpack("B B B B",
                -- Quantized.
                -- floor(floor(rWheel * rMax + 0.5) * rRatio + 0.5),
                -- floor(floor(gWheel * gMax + 0.5) * gRatio + 0.5),
                -- floor(floor(bWheel * bMax + 0.5) * bRatio + 0.5),

                -- Not quantized.
                floor(rWheel * 255 + 0.5),
                floor(gWheel * 255 + 0.5),
                floor(bWheel * 255 + 0.5),

                255)
        elseif sqMag < sqRie then
            -- Inscribed triangle.
            local xbw <const> = xNorm - xTri3
            local ybw <const> = yNorm - yTri3
            local w1 <const> = (yDiff2_3 * xbw + xDiff3_2 * ybw) * bwDnmInv
            local w2 <const> = (yDiff3_1 * xbw + xDiff1_3 * ybw) * bwDnmInv
            local w3 <const> = 1.0 - w1 - w2

            if w1 >= 0.0 and w1 <= 1.0
                and w2 >= 0.0 and w2 <= 1.0
                and w3 >= 0.0 and w3 <= 1.0 then
                local wSum <const> = w1 + w2 + w3
                local wSumInv <const> = wSum ~= 0.0 and 1.0 / wSum or 0.0
                -- w2 is white, w3 is black.
                -- Black saturation is undefined in HSV.
                local v <const> = (w1 + w2) * wSumInv
                local u <const> = (w1 + w3) * wSumInv

                local diagSq <const> = u * u + v * v
                local coeff <const> = diagSq <= 0.0 and 0.0 or w2

                local rTri <const> = (w1 * rBase + coeff) * wSumInv
                local gTri <const> = (w1 * gBase + coeff) * wSumInv
                local bTri <const> = (w1 * bBase + coeff) * wSumInv

                -- Quantized base.
                -- local rTri <const> = (w1 * rbQuantized + coeff) * wSumInv
                -- local gTri <const> = (w1 * gbQuantized + coeff) * wSumInv
                -- local bTri <const> = (w1 * bbQuantized + coeff) * wSumInv

                byteStr = strpack("B B B B",
                    -- Quantized
                    -- floor(floor(rTri * rMax + 0.5) * rRatio + 0.5),
                    -- floor(floor(gTri * gMax + 0.5) * gRatio + 0.5),
                    -- floor(floor(bTri * bMax + 0.5) * bRatio + 0.5),

                    -- Not quantized.
                    floor(rTri * 255 + 0.5),
                    floor(gTri * 255 + 0.5),
                    floor(bTri * 255 + 0.5),

                    255)
            end -- End ws inbounds check.
        end     -- End square mag check.

        i = i + 1
        byteStrs[i] = byteStr
    end -- End image loop.

    -- Draw picker canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvas,
        height = hCanvas,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }
    local img <const> = Image(imgSpec)
    local drawRect <const> = Rectangle(0, 0, wCanvas, hCanvas)
    img.bytes = table.concat(byteStrs)
    ctx:drawImage(img, drawRect, drawRect)

    local swatchSize <const> = defaults.swatchSize
    local offset <const> = swatchSize // 2

    -- Draw background color swatch.
    ctx.color = Color {
        red = floor(redBack * 255 + 0.5),
        green = floor(greenBack * 255 + 0.5),
        blue = floor(blueBack * 255 + 0.5),
        alpha = 255
    }
    ctx:fillRect(Rectangle(
        offset, hCanvas - swatchSize - 1,
        swatchSize, swatchSize))

    -- Draw foreground color swatch.
    ctx.color = Color {
        red = floor(redFore * 255 + 0.5),
        green = floor(greenFore * 255 + 0.5),
        blue = floor(blueFore * 255 + 0.5),
        alpha = 255
    }
    ctx:fillRect(Rectangle(
        0, hCanvas - swatchSize - 1 - offset,
        swatchSize, swatchSize))

    -- If dialog is wide enough, draw diagnostic text.
    if (wCanvas - hCanvas) > defaults.textDisplayLimit
        and rCanvas > (swatchSize + swatchSize) then
        local textSize <const> = ctx:measureText("E")
        local yIncr <const> = textSize.height + 4

        local textColor <const> = themeColors.text
        ctx.color = textColor

        local satActive = isBackActive
            and active.satBack
            or active.satFore
        local valActive = isBackActive
            and active.valBack
            or active.valFore

        if valActive > 0.0 and satActive > 0.0 then
            ctx:fillText(string.format(
                "H: %.2f", hueActive * 360), 2, 2)
        end

        if valActive > 0.0 then
            ctx:fillText(string.format(
                "S: %.2f%%", satActive * 100), 2, 2 + yIncr)
        end

        ctx:fillText(string.format(
            "V: %.2f%%", valActive * 100), 2, 2 + yIncr * 2)

        local redActive <const> = isBackActive
            and redBack
            or redFore
        local greenActive <const> = isBackActive
            and greenBack
            or greenFore
        local blueActive <const> = isBackActive
            and blueBack
            or blueFore
        local alphaActive <const> = isBackActive
            and alphaBack
            or alphaFore

        ctx:fillText(string.format(
            "R: %.2f%%", redActive * 100), 2, 2 + yIncr * 4)
        ctx:fillText(string.format(
            "G: %.2f%%", greenActive * 100), 2, 2 + yIncr * 5)
        ctx:fillText(string.format(
            "B: %.2f%%", blueActive * 100), 2, 2 + yIncr * 6)
        ctx:fillText(string.format(
            "A: %.2f%%", alphaActive * 100), 2, 2 + yIncr * 8)

        local r8 <const> = floor(redActive * 255 + 0.5)
        local g8 <const> = floor(greenActive * 255 + 0.5)
        local b8 <const> = floor(blueActive * 255 + 0.5)

        ctx:fillText(string.format(
            "#%06x", r8 << 0x10|g8 << 0x08|b8), 2, 2 + yIncr * 10)
    end
end

local dlg <const> = Dialog { title = "Color Picker" }

dlg:canvas {
    id = "triCanvas",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvas,
    onpaint = onPaint,
}

dlg:newrow { always = false }

dlg:slider {
    id = "rLevels",
    value = defaults.rLevels,
    min = 1,
    max = 8,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local rLevels <const> = args.rLevels --[[@as integer]]
        active.rMax = (1 << rLevels) - 1.0
        updateActiveFromLevels()
        dlg:repaint()
    end
}

dlg:slider {
    id = "gLevels",
    value = defaults.gLevels,
    min = 1,
    max = 8,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local gLevels <const> = args.gLevels --[[@as integer]]
        active.gMax = (1 << gLevels) - 1.0
        updateActiveFromLevels()
        dlg:repaint()
    end
}

dlg:slider {
    id = "bLevels",
    value = defaults.bLevels,
    min = 1,
    max = 8,
    focus = false,
    onchange = function()
        local args <const> = dlg.data
        local bLevels <const> = args.bLevels --[[@as integer]]
        active.bMax = (1 << bLevels) - 1.0
        updateActiveFromLevels()
        dlg:repaint()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "getForeButton",
    text = "&FORE",
    onclick = function()
        local fgColor <const> = app.fgColor
        local r8 <const> = fgColor.red
        local g8 <const> = fgColor.green
        local b8 <const> = fgColor.blue
        local t8 <const> = fgColor.alpha
        updateActiveFromRgba8(r8, g8, b8, t8, false)
        dlg:repaint()
    end
}

dlg:button {
    id = "getBackButton",
    text = "&BACK",
    onclick = function()
        app.command.SwitchColors()
        local fgColor <const> = app.fgColor
        local r8 <const> = fgColor.red
        local g8 <const> = fgColor.green
        local b8 <const> = fgColor.blue
        local t8 <const> = fgColor.alpha
        app.command.SwitchColors()
        updateActiveFromRgba8(r8, g8, b8, t8, true)
        dlg:repaint()
    end
}

dlg:button {
    id = "exitButton",
    text = "&X",
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = false,
    wait = false
}