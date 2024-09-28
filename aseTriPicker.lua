local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919
local sqrt3_2 <const> = 0.86602540378444

local defaults <const> = {
    -- TODO: Alpha adjustment slider?
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
    shiftLevels = 24,
}

local active <const> = {
    wCanvas = defaults.wCanvas,
    hCanvas = defaults.hCanvas,

    rMax = 255.0,
    gMax = 255.0,
    bMax = 255.0,

    hueFore = defaults.hue,
    satFore = defaults.sat,
    valFore = defaults.val,

    hqFore = defaults.hue,
    sqFore = defaults.sat,
    vqFore = defaults.val,

    redFore = defaults.red,
    greenFore = defaults.green,
    blueFore = defaults.blue,

    alphaFore = defaults.alpha,

    hueBack = defaults.hue,
    satBack = defaults.sat,
    valBack = defaults.val,

    hqBack = defaults.hue,
    sqBack = defaults.sat,
    vqBack = defaults.val,

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

    if mx < 0.00001 then return 0.0, 0.0, 0.0 end

    local mn <const> = math.min(r, gbmn)
    local chroma <const> = mx - mn

    if chroma < 0.00001 then return 0.0, 0.0, mx end

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
            active.hqFore = hqFore
        end
        active.sqFore = sqFore
    end
    active.vqFore = vqFore

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
            active.hqBack = hqBack
        end
        active.sqBack = sqBack
    end
    active.vqBack = vqBack
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

    local r01 <const>, g01 <const>, b01 <const> = r8 / 255.0, g8 / 255.0, b8 / 255.0
    local rq <const> = rMax ~= 0.0 and math.floor((r01) * rMax + 0.5) / rMax or 0.0
    local gq <const> = gMax ~= 0.0 and math.floor((g01) * gMax + 0.5) / gMax or 0.0
    local bq <const> = bMax ~= 0.0 and math.floor((b01) * bMax + 0.5) / bMax or 0.0

    local hueQuantized <const>,
    satQuantized <const>,
    valQuantized <const> = rgbToHsv(rq, gq, bq)

    local hueOrig <const>,
    satOrig <const>,
    valOrig <const> = rgbToHsv(r01, g01, b01)

    if isBack then
        if valOrig > 0.0 then
            if satOrig > 0.0 then
                active.hueBack = hueOrig
            end
            active.satBack = satOrig
        end
        active.valBack = valOrig

        if valQuantized > 0.0 then
            if satQuantized > 0.0 then
                active.hqBack = hueQuantized
            end
            active.sqBack = satQuantized
        end
        active.vqBack = valQuantized

        active.redBack = rq
        active.greenBack = gq
        active.blueBack = bq

        active.alphaBack = t8 / 255.0
    else
        if valOrig > 0.0 then
            if satOrig > 0.0 then
                active.hueFore = hueOrig
            end
            active.satFore = satOrig
        end
        active.valFore = valOrig

        if valQuantized > 0.0 then
            if satQuantized > 0.0 then
                active.hqFore = hueQuantized
            end
            active.sqFore = satQuantized
        end
        active.vqFore = valQuantized

        active.redFore = rq
        active.greenFore = gq
        active.blueFore = bq

        active.alphaFore = t8 / 255.0
    end
end

---@param event { context: GraphicsContext }
local function onPaint(event)
    local angOffsetRadians <const> = defaults.angOffsetRadians or 0.0
    local ringInEdge <const> = defaults.ringInEdge or 0.9
    local sqRie <const> = ringInEdge * ringInEdge

    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end
    active.wCanvas = wCanvas
    active.hCanvas = hCanvas

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local rCanvas <const> = (shortEdge - 1.0) * 0.5
    local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

    local rMax <const> = active.rMax or 1.0
    local gMax <const> = active.gMax or 1.0
    local bMax <const> = active.bMax or 1.0

    local rRatio <const> = 255.0 / rMax
    local gRatio <const> = 255.0 / gMax
    local bRatio <const> = 255.0 / bMax

    local redBack <const> = active.redBack or 0.0
    local greenBack <const> = active.greenBack or 0.0
    local blueBack <const> = active.blueBack or 0.0
    local alphaBack <const> = active.alphaBack or 1.0

    local redFore <const> = active.redFore or 0.0
    local greenFore <const> = active.greenFore or 0.0
    local blueFore <const> = active.blueFore or 0.0
    local alphaFore <const> = active.alphaFore or 1.0

    local isBackActive <const> = active.isBackActive
    local hueActive = isBackActive
        and (active.hueBack or 0.0)
        or (active.hueFore or 0.0)

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
                floor(floor(rWheel * rMax + 0.5) * rRatio + 0.5),
                floor(floor(gWheel * gMax + 0.5) * gRatio + 0.5),
                floor(floor(bWheel * bMax + 0.5) * bRatio + 0.5),

                -- Not quantized.
                -- floor(rWheel * 255 + 0.5),
                -- floor(gWheel * 255 + 0.5),
                -- floor(bWheel * 255 + 0.5),

                255)
        elseif sqMag < sqRie then
            -- TODO: Move the triangle mouse move part into its own function,
            -- as it should be called both by mouse down and mouse move.

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

                byteStr = strpack("B B B B",
                    -- Quantized
                    floor(floor(rTri * rMax + 0.5) * rRatio + 0.5),
                    floor(floor(gTri * gMax + 0.5) * gRatio + 0.5),
                    floor(floor(bTri * bMax + 0.5) * bRatio + 0.5),

                    -- Not quantized.
                    -- floor(rTri * 255 + 0.5),
                    -- floor(gTri * 255 + 0.5),
                    -- floor(bTri * 255 + 0.5),

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

        local hqActive <const> = isBackActive
            and (active.hqBack or 0.0)
            or (active.hqFore or 0.0)
        local sqActive <const> = isBackActive
            and (active.sqBack or 0.0)
            or (active.sqFore or 0.0)
        local vqActive <const> = isBackActive
            and (active.vqBack or 0.0)
            or (active.vqFore or 0.0)

        if vqActive > 0.0 and sqActive > 0.0 then
            ctx:fillText(string.format(
                "H: %.2f", hqActive * 360), 2, 2)
            -- print(string.format(
            --     "H: %.2f", hqActive * 360))
        end

        if vqActive > 0.0 then
            ctx:fillText(string.format(
                "S: %.2f%%", sqActive * 100), 2, 2 + yIncr)
            -- print(string.format(
            --     "S: %.2f%%", sqActive * 100))
        end

        ctx:fillText(string.format(
            "V: %.2f%%", vqActive * 100), 2, 2 + yIncr * 2)
        -- print(string.format(
        --     "V: %.2f%%", vqActive * 100))

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

        -- print(string.format(
        --     "R: %.2f%%", redActive * 100))
        -- print(string.format(
        --     "G: %.2f%%", greenActive * 100))
        -- print(string.format(
        --     "B: %.2f%%", blueActive * 100))
        -- print(string.format(
        --     "A: %.2f%%", alphaActive * 100))

        local r8 <const> = floor(redActive * 255 + 0.5)
        local g8 <const> = floor(greenActive * 255 + 0.5)
        local b8 <const> = floor(blueActive * 255 + 0.5)

        ctx:fillText(string.format(
            "#%06X", r8 << 0x10|g8 << 0x08|b8), 2, 2 + yIncr * 10)
        -- print(string.format(
        --     "#%06X", r8 << 0x10| g8 << 0x08 | b8))
    end
end

local dlg <const> = Dialog { title = "Color Picker" }

---@param event MouseEvent
local function onMouseMove(event)
    if event.button == MouseButton.NONE then return end

    local isRing <const> = active.mouseDownRing
    local isTri <const> = active.mouseDownTri
    if (not isRing) and (not isTri) then return end

    local xMouseMove <const> = event.x
    local yMouseMove <const> = event.y

    local wCanvas <const> = active.wCanvas or 200
    local hCanvas <const> = active.hCanvas or 200
    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local rCanvas <const> = (shortEdge - 1.0) * 0.5
    local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

    local xDelta <const> = xMouseMove - xCenter
    local yDelta <const> = yCenter - yMouseMove

    local xNorm <const> = xDelta * rCanvasInv
    local yNorm <const> = yDelta * rCanvasInv

    local isBackActive <const> = active.isBackActive
    local alphaWheel <const> = isBackActive
        and (active.alphaBack or 1.0)
        or (active.alphaFore or 1.0)

    if isRing then
        local angSigned <const> = math.atan(yNorm, xNorm)
        local angOffsetRadians <const> = defaults.angOffsetRadians or 0.0
        local hwSigned = (angSigned + angOffsetRadians) * oneTau
        if event.shiftKey then
            local shiftLevels <const> = defaults.shiftLevels or 24
            hwSigned = math.floor(0.5 + hwSigned * shiftLevels) / shiftLevels
        end
        local hueWheel = hwSigned - math.floor(hwSigned)

        local satWheel <const> = isBackActive
            and (active.satBack or 0.0)
            or (active.satFore or 0.0)
        local valWheel <const> = isBackActive
            and (active.valBack or 0.0)
            or (active.valFore or 0.0)

        local r01 <const>, g01 <const>, b01 <const> = hsvToRgb(hueWheel, satWheel, valWheel)

        local rMax <const> = active.rMax
        local gMax <const> = active.gMax
        local bMax <const> = active.bMax

        local rq <const> = math.floor(r01 * rMax + 0.5) / rMax
        local gq <const> = math.floor(g01 * gMax + 0.5) / gMax
        local bq <const> = math.floor(b01 * bMax + 0.5) / bMax

        local r8 <const> = math.floor(rq * 255.0 + 0.5)
        local g8 <const> = math.floor(gq * 255.0 + 0.5)
        local b8 <const> = math.floor(bq * 255.0 + 0.5)
        local t8 <const> = math.floor(alphaWheel * 255.0 + 0.5)

        local hq <const>, sq <const>, vq <const> = rgbToHsv(rq, gq, bq)

        if isBackActive then
            active.hueBack = hueWheel

            active.redBack = rq
            active.greenBack = gq
            active.blueBack = bq

            if vq > 0.0 then
                if sq > 0.0 then
                    active.hqBack = hq
                end
                active.sqBack = sq
            end
            active.vqBack = vq

            app.command.SwitchColors()
            app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
            app.command.SwitchColors()
        else
            active.hueFore = hueWheel

            active.redFore = rq
            active.greenFore = gq
            active.blueFore = bq

            if vq > 0.0 then
                if sq > 0.0 then
                    active.hqFore = hq
                end
                active.sqFore = sq
            end
            active.vqFore = vq

            app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
        end
    elseif isTri then
        local ringInEdge <const> = defaults.ringInEdge or 0.0
        local angOffsetRadians <const> = defaults.angOffsetRadians or 0.0

        local hueActive <const> = isBackActive
            and (active.hueBack or 0.0)
            or (active.hueFore or 0.0)

        -- Find main point of the triangle.
        local hActiveTheta <const> = (hueActive * tau) - angOffsetRadians
        local xTri1 <const> = ringInEdge * math.cos(hActiveTheta)
        local yTri1 <const> = ringInEdge * math.sin(hActiveTheta)

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
        local yDiff2_3 <const> = yTri2 - yTri3
        local xDiff1_3 <const> = xTri1 - xTri3
        local xDiff3_2 <const> = xTri3 - xTri2
        local yDiff1_3 <const> = yTri1 - yTri3
        local yDiff3_1 <const> = yTri3 - yTri1
        local bwDenom <const> = yDiff2_3 * xDiff1_3 + xDiff3_2 * yDiff1_3
        local bwDnmInv <const> = bwDenom ~= 0.0 and 1.0 / bwDenom or 0.0

        local xbw <const> = xNorm - xTri3
        local ybw <const> = yNorm - yTri3
        local w1 <const> = math.min(math.max(
            (yDiff2_3 * xbw + xDiff3_2 * ybw) * bwDnmInv,
            0.0), 1.0)
        local w2 <const> = math.min(math.max(
            (yDiff3_1 * xbw + xDiff1_3 * ybw) * bwDnmInv,
            0.0), 1.0)
        local w3 <const> = math.min(math.max(
            1.0 - w1 - w2,
            0.0), 1.0)

        local wSum <const> = w1 + w2 + w3
        local wSumInv <const> = wSum ~= 0.0 and 1.0 / wSum or 0.0

        -- w2 is white, w3 is black.
        -- Black saturation is undefined in HSV.
        local v <const> = (w1 + w2) * wSumInv
        local u <const> = (w1 + w3) * wSumInv

        local diagSq <const> = u * u + v * v
        local coeff <const> = diagSq <= 0.0 and 0.0 or w2

        local rBase <const>, gBase <const>, bBase <const> = hsvToRgb(hueActive, 1.0, 1.0)

        local r01 <const> = (w1 * rBase + coeff) * wSumInv
        local g01 <const> = (w1 * gBase + coeff) * wSumInv
        local b01 <const> = (w1 * bBase + coeff) * wSumInv

        local rMax <const> = active.rMax or 1.0
        local gMax <const> = active.gMax or 1.0
        local bMax <const> = active.bMax or 1.0

        local rq <const> = math.floor(r01 * rMax + 0.5) / rMax
        local gq <const> = math.floor(g01 * gMax + 0.5) / gMax
        local bq <const> = math.floor(b01 * bMax + 0.5) / bMax

        local r8 <const> = math.floor(rq * 255.0 + 0.5)
        local g8 <const> = math.floor(gq * 255.0 + 0.5)
        local b8 <const> = math.floor(bq * 255.0 + 0.5)
        local t8 <const> = math.floor(alphaWheel * 255.0 + 0.5)

        local _ <const>, so <const>, vo <const> = rgbToHsv(r01, g01, b01)
        local hq <const>, sq <const>, vq <const> = rgbToHsv(rq, gq, bq)

        if isBackActive then
            active.redBack = rq
            active.greenBack = gq
            active.blueBack = bq

            if vo > 0.0 then
                if so > 0.0 then
                    active.satBack = so
                end
            end
            active.valBack = vo

            if vq > 0.0 then
                if sq > 0.0 then
                    active.hqBack = hq
                end
                active.sqBack = sq
            end
            active.vqBack = vq

            app.command.SwitchColors()
            app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
            app.command.SwitchColors()
        else
            active.redFore = rq
            active.greenFore = gq
            active.blueFore = bq

            if vo > 0.0 then
                if so > 0.0 then
                    active.satFore = so
                end
            end
            active.valFore = vo

            if vq > 0.0 then
                if sq > 0.0 then
                    active.hqFore = hq
                end
                active.sqFore = sq
            end
            active.vqFore = vq

            app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
        end -- End front or back color check.
    end     -- End is in tri or wheel check.

    dlg:repaint()
end

---@param event MouseEvent
local function onMouseDown(event)
    local xMouseDown <const> = event.x
    local yMouseDown <const> = event.y

    local ringInEdge <const> = defaults.ringInEdge or 0.9
    local sqRie <const> = ringInEdge * ringInEdge

    local wCanvas <const> = active.wCanvas or 200
    local hCanvas <const> = active.hCanvas or 200
    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local rCanvas <const> = (shortEdge - 1.0) * 0.5
    local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

    local xDelta <const> = xMouseDown - xCenter
    local yDelta <const> = yCenter - yMouseDown

    local xNorm <const> = xDelta * rCanvasInv
    local yNorm <const> = yDelta * rCanvasInv

    local sqMag <const> = xNorm * xNorm + yNorm * yNorm
    if (not active.mouseDownTri) and (sqMag >= sqRie and sqMag <= 1.0) then
        active.mouseDownRing = true
        if event.button == MouseButton.RIGHT then
            active.isBackActive = true
        end
    end

    if (not active.mouseDownRing) and (sqMag < sqRie) then
        active.mouseDownTri = true
        if event.button == MouseButton.RIGHT then
            active.isBackActive = true
        end
    end

    onMouseMove(event)
end

---@param event MouseEvent
local function onMouseUp(event)
    local xMouseUp <const> = event.x
    local yMouseUp <const> = event.y

    active.mouseDownRing = false
    active.mouseDownTri = false
    active.isBackActive = false

    local swatchSize <const> = defaults.swatchSize
    local offset <const> = swatchSize // 2
    local hCanvas <const> = active.hCanvas
    if xMouseUp >= 0 and xMouseUp < offset + swatchSize
        and yMouseUp >= hCanvas - swatchSize - 1 - offset
        and yMouseUp < hCanvas then
        local hTemp <const> = active.hueBack
        local sTemp <const> = active.satBack
        local vTemp <const> = active.valBack

        local hqTemp <const> = active.hqBack
        local sqTemp <const> = active.sqBack
        local vqTemp <const> = active.vqBack

        local aTemp <const> = active.alphaBack
        local rTemp <const> = active.redBack
        local gTemp <const> = active.greenBack
        local bTemp <const> = active.blueBack

        active.hueBack = active.hueFore
        active.satBack = active.satFore
        active.valBack = active.valFore

        active.hqBack = active.hqFore
        active.sqBack = active.sqFore
        active.vqBack = active.vqFore

        active.alphaBack = active.alphaFore

        active.redBack = active.redFore
        active.greenBack = active.greenFore
        active.blueBack = active.blueFore

        active.hueFore = hTemp
        active.satFore = sTemp
        active.valFore = vTemp

        active.hqFore = hqTemp
        active.sqFore = sqTemp
        active.vqFore = vqTemp

        active.alphaFore = aTemp

        active.redFore = rTemp
        active.greenFore = gTemp
        active.blueFore = bTemp

        dlg:repaint()
        app.command.SwitchColors()
    end
end

dlg:canvas {
    id = "triCanvas",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvas,
    onmousedown = onMouseDown,
    onmousemove = onMouseMove,
    onmouseup = onMouseUp,
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
        local rLevels <const> = args.rLevels or 8 --[[@as integer]]
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
        local gLevels <const> = args.gLevels or 8 --[[@as integer]]
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
        local bLevels <const> = args.bLevels or 8 --[[@as integer]]
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
        local bgColor <const> = app.fgColor
        local r8 <const> = bgColor.red
        local g8 <const> = bgColor.green
        local b8 <const> = bgColor.blue
        local t8 <const> = bgColor.alpha
        app.command.SwitchColors()
        updateActiveFromRgba8(r8, g8, b8, t8, true)
        dlg:repaint()
    end
}

dlg:button {
    id = "pickButton",
    text = "P&ICK",
    onclick = function()
        local editor <const> = app.editor
        if not editor then return end

        local mouse <const> = editor.spritePos
        local x = mouse.x
        local y = mouse.y

        local sprite <const> = app.sprite
        if not sprite then return end

        local frame <const> = app.frame or sprite.frames[1]

        local docPrefs <const> = app.preferences.document(sprite)
        local tiledMode <const> = docPrefs.tiled.mode

        if tiledMode == 3 then
            -- Tiling on both axes.
            x = x % sprite.width
            y = y % sprite.height
        elseif tiledMode == 2 then
            -- Vertical tiling.
            y = y % sprite.height
        elseif tiledMode == 1 then
            -- Horizontal tiling.
            x = x % sprite.width
        end

        local spriteSpec <const> = sprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local mouseSpec <const> = ImageSpec {
            width = 1,
            height = 1,
            colorMode = colorMode,
            transparentColor = spriteSpec.transparentColor
        }
        mouseSpec.colorSpace = spriteSpec.colorSpace
        local flat <const> = Image(mouseSpec)
        flat:drawSprite(sprite, frame, Point(-x, -y))
        local bpp <const> = flat.bytesPerPixel
        local bytes <const> = flat.bytes
        local pixel <const> = string.unpack("<I" .. bpp, bytes)

        -- print(string.format("x: %d, y: %d, p: %x", x, y, pixel))

        local r8, g8, b8, t8 = 0, 0, 0, 0
        if colorMode == ColorMode.INDEXED then
            local palette <const> = sprite.palettes[1]
            local lenPalette <const> = #palette
            if pixel >= 0 and pixel < lenPalette then
                local aseColor <const> = palette:getColor(pixel)
                r8 = aseColor.red
                g8 = aseColor.green
                b8 = aseColor.blue
                t8 = aseColor.alpha
            end
        elseif colorMode == ColorMode.GRAY then
            local v8 <const> = pixel >> 0x00 & 0xff
            r8, g8, b8 = v8, v8, v8
            t8 = pixel >> 0x08 & 0xff
        else
            r8 = pixel >> 0x00 & 0xff
            g8 = pixel >> 0x08 & 0xff
            b8 = pixel >> 0x10 & 0xff
            t8 = pixel >> 0x18 & 0xff
        end

        if t8 > 0 then
            updateActiveFromRgba8(r8, g8, b8, t8, false)
            dlg:repaint()
            app.fgColor = Color {
                r = math.floor(active.redFore * 255 + 0.5),
                g = math.floor(active.greenFore * 255 + 0.5),
                b = math.floor(active.blueFore * 255 + 0.5),
                a = math.floor(active.alphaFore * 255 + 0.5)
            }
        end
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