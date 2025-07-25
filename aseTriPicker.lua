local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919
local sqrt3_2 <const> = 0.86602540378444

local screenScale = 1
if app.preferences then
    local generalPrefs <const> = app.preferences.general
    if generalPrefs then
        local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
        if ssCand and ssCand > 0 then
            screenScale = ssCand
        end
    end
end

local defaults <const> = {
    -- Might be nice to have an inner radius where the mouse stops responding
    -- to hue ring shift... but it causes ring to jump when mouse moves from
    -- deadzone back into into valid magnitude.

    lockTriRot = false,
    ringInEdge = 0.88,
    angOffsetRadians = 0.5235987755983,
    angLockRadians = 0.0,

    wCanvasMain = math.max(16, 200 // screenScale),
    hCanvasMain = math.max(16, 200 // screenScale),
    wCanvasAlpha = math.max(16, 200 // screenScale),
    hCanvasAlpha = math.max(8, 12 // screenScale),
    wCanvasHex = math.max(16, 100 // screenScale),
    hCanvasHex = math.max(4, 16 // screenScale),

    reticleSize = math.max(3, 6 // screenScale),
    reticleStroke = math.max(1, 1 // screenScale),
    swatchSize = math.max(4, 17 // screenScale),
    swatchMargin = math.max(3, 6 // screenScale),

    showAlphaBar = false,
    showForeButton = true,
    showBackButton = true,
    showPalAppendButton = false,
    showSampleButton = false,
    showHexButton = false,
    showExitButton = true,

    rBitDepth = 8,
    gBitDepth = 8,
    bBitDepth = 8,
    bitDepthsNote = "Format: RGB888",

    hue = 0.0,
    sat = 1.0,
    val = 1.0,
    alpha = 1.0,

    red = 1.0,
    green = 0.0,
    blue = 0.0,
    hexCode = "000000",

    textDisplayLimit = 50,
    shiftLevels = 24,

    foreKey = "&FORE",
    backKey = "&BACK",
    palAppendKey = "A&PPEND",
    sampleKey = "S&AMPLE",
    hexKey = "&HEX",
    optionsKey = "&+",
    exitKey = "&X",

    hueStep = 0.0013180565309174,
    satStep = 1.0 / 255.0,
    valStep = 1.0 / 255.0,
    shiftScalar = 5.0,

    -- https://developer.mozilla.org/en-US/docs/Web/
    -- API/UI_Events/Keyboard_event_code_values
    -- The issue with arrow keys is that when a selection is being
    -- transformed, these inputs get eaten. Other keys, like WASD
    -- and QE interfere with magic wand, etc. For now, saturation
    -- nudging needs Alt key.
    hueIncrKey = "ArrowRight",
    hueDecrKey = "ArrowLeft",
    satIncrKey = "ArrowUp",
    satDecrKey = "ArrowDown",
    valIncrKey = "ArrowUp",
    valDecrKey = "ArrowDown",

    aCheck = 0.25,
    bCheck = 0.4,
    wCheck = math.max(1, 6 // screenScale),
    hCheck = math.max(1, 6 // screenScale),
}

local active <const> = {
    lockTriRot = defaults.lockTriRot,
    ringInEdge = defaults.ringInEdge,
    angOffsetRadians = defaults.angOffsetRadians,
    angLockRadians = 0.0,

    wCanvasMain = defaults.wCanvasMain,
    hCanvasMain = defaults.hCanvasMain,
    triggerRingRepaint = true,
    ringBytes = "",
    triggerTriRepaint = true,
    triBytes = "",

    showAlphaBar = defaults.showAlphaBar,
    wCanvasAlpha = defaults.wCanvasAlpha,
    hCanvasAlpha = defaults.hCanvasAlpha,
    triggerAlphaRepaint = true,
    byteStrAlpha = "",

    rBitDepth = 8,
    gBitDepth = 8,
    bBitDepth = 8,

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

    hueBack = defaults.hue + 0.5,
    satBack = defaults.sat,
    valBack = defaults.val,

    hqBack = defaults.hue + 0.5,
    sqBack = defaults.sat,
    vqBack = defaults.val,

    redBack = 1.0 - defaults.red,
    greenBack = 1.0 - defaults.green,
    blueBack = 1.0 - defaults.blue,

    alphaBack = defaults.alpha,

    isBackActive = false,
    mouseDownRing = false,
    mouseDownTri = false,
}

---@param r01 number
---@param g01 number
---@param b01 number
---@return string
local function rgbToHexStr(r01, g01, b01)
    local rBitDepth <const> = active.rBitDepth
    local gBitDepth <const> = active.gBitDepth
    local bBitDepth <const> = active.bBitDepth

    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    local is555 <const> = rBitDepth == 5
        and gBitDepth == 5
        and bBitDepth == 5

    local shift0 <const> = is555 and 0 or bBitDepth + gBitDepth
    local shift1 <const> = bBitDepth
    local shift2 <const> = is555 and bBitDepth + gBitDepth or 0

    local hex <const> = math.floor(r01 * rMax + 0.5) << shift0
        | math.floor(g01 * gMax + 0.5) << shift1
        | math.floor(b01 * bMax + 0.5) << shift2

    local hexPad <const> = math.ceil((rBitDepth
        + gBitDepth
        + bBitDepth) * 0.25)
    local hexStr <const> = string.format("%0" .. hexPad .. "X", hex)

    return hexStr
end

---@param hexCode string
---@return boolean isValid
---@return number r
---@return number g
---@return number b
local function hexStrToRgb(hexCode)
    local hexCodeVerif = hexCode
    if string.sub(hexCode, 1, 1) == '#' then
        hexCodeVerif = string.sub(hexCode, 2)
    end

    local hcParsed <const> = tonumber(hexCodeVerif, 16)
    if not hcParsed then return false, 0.0, 0.0, 0.0 end

    -- print(string.format("hcParsed: %08x", hcParsed))

    local rBitDepth <const> = active.rBitDepth
    local gBitDepth <const> = active.gBitDepth
    local bBitDepth <const> = active.bBitDepth

    -- print(string.format(
    --     "rBitDepth: %d, gBitDepth: %d, bBitDepth: %d",
    --     rBitDepth, gBitDepth, bBitDepth))

    local rShift <const> = bBitDepth + gBitDepth
    local gShift <const> = bBitDepth
    local bShift <const> = 0

    -- print(string.format(
    --     "rShift: %d, gShift: %d, bShift: %d",
    --     rShift, gShift, bShift))

    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    -- print(string.format(
    --     "rMax: %d, gMax: %d, bMax: %d",
    --     rMax, gMax, bMax))

    -- It's possible in, e.g., RGB555, to enter a code such as
    -- #ABCD which exceeds the limit and will be truncated to #2BCD,
    -- causing confusion.
    -- local hcLimit <const> = (rMax << rShift)
    --     | (gMax << gShift)
    --     | (bMax << bShift)

    local rx = (hcParsed >> rShift) & rMax
    local gx <const> = (hcParsed >> gShift) & gMax
    local bx = (hcParsed >> bShift) & bMax

    local is555 <const> = rBitDepth == 5
        and gBitDepth == 5
        and bBitDepth == 5
    if is555 then rx, bx = bx, rx end

    -- print(string.format(
    --     "rx: %d (0x%x), gx: %d (0x%x), bx: %d (0x%x)",
    --     rx, rx, gx, gx, bx, bx))

    local r01 <const> = rMax > 0.0 and rx / rMax or 0.0
    local g01 <const> = gMax > 0.0 and gx / gMax or 0.0
    local b01 <const> = bMax > 0.0 and bx / bMax or 0.0

    -- print(string.format(
    --     "r01: %03f, g01: %03f, b01: %03f",
    --     r01, g01, b01))

    return true, r01, g01, b01
end

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
    elseif sector == 6 then
        return v, tint3, tint1
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

---@param event { context: GraphicsContext }
local function onPaintAlpha(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local needsRepaint <const> = active.triggerAlphaRepaint
        or active.wCanvasAlpha ~= wCanvas
        or active.hCanvasAlpha ~= hCanvas

    active.wCanvasAlpha = wCanvas
    active.hCanvasAlpha = hCanvas

    local isBackActive <const> = active.isBackActive
    local redActive <const> = isBackActive
        and active.redBack
        or active.redFore
    local greenActive <const> = isBackActive
        and active.greenBack
        or active.greenFore
    local blueActive <const> = isBackActive
        and active.blueBack
        or active.blueFore
    local alphaActive <const> = isBackActive
        and active.alphaBack
        or active.alphaFore

    if needsRepaint then
        ---@type string[]
        local byteStrs <const> = {}

        local strpack <const> = string.pack
        local floor <const> = math.floor

        local wCheck <const> = defaults.wCheck
        local hCheck <const> = defaults.hCheck
        local aCheck <const> = defaults.aCheck
        local bCheck <const> = defaults.bCheck
        local xToFac <const> = 1.0 / (wCanvas - 1.0)

        local lenCanvas <const> = wCanvas * hCanvas
        local i = 0
        while i < lenCanvas do
            local y <const> = i // wCanvas
            local x <const> = i % wCanvas
            local t <const> = x * xToFac

            local cCheck = bCheck
            if (((x // wCheck) + (y // hCheck)) % 2) ~= 1 then
                cCheck = aCheck
            end

            local ucCheck <const> = (1.0 - t) * cCheck
            local byteStr <const> = strpack("B B B B",
                floor((ucCheck + t * redActive) * 255 + 0.5),
                floor((ucCheck + t * greenActive) * 255 + 0.5),
                floor((ucCheck + t * blueActive) * 255 + 0.5),
                255)

            i = i + 1
            byteStrs[i] = byteStr
        end -- End image loop.

        active.byteStrAlpha = table.concat(byteStrs)
        active.triggerAlphaRepaint = false
    end -- End needs repaint.

    -- Draw alpha canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvas,
        height = hCanvas,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }
    local img <const> = Image(imgSpec)
    img.bytes = active.byteStrAlpha
    local drawRect <const> = Rectangle(0, 0, wCanvas, hCanvas)
    ctx:drawImage(img, drawRect, drawRect)

    local xReticle <const> = math.floor(alphaActive * (wCanvas - 1.0) + 0.5)
    local yReticle <const> = hCanvas // 2

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2

    local relLum <const> = (0.30 * redActive
        + 0.59 * greenActive
        + 0.11 * blueActive)
    local reticleColor <const> = relLum < 0.5 and
        Color { r = 255, g = 255, b = 255, a = 255 }
        or Color { r = 0, g = 0, b = 0, a = 255 }
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.reticleStroke
    ctx:strokeRect(Rectangle(
        xReticle - reticleHalf, yReticle - reticleHalf,
        reticleSize, reticleSize))
end

---@param event { context: GraphicsContext }
local function onPaintMain(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local needsRepaintResize <const> = active.wCanvasMain ~= wCanvas
        or active.hCanvasMain ~= hCanvas
    local needsRingRepaint <const> = active.triggerRingRepaint
        or needsRepaintResize
    local needsTriRepaint <const> = active.triggerTriRepaint
        or needsRepaintResize

    active.wCanvasMain = wCanvas
    active.hCanvasMain = hCanvas

    local angOffsetRadians <const> = active.angOffsetRadians
    local lockTriRot <const> = active.lockTriRot
    local ringInEdge <const> = active.ringInEdge
    local sqRie <const> = ringInEdge * ringInEdge

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local rCanvas <const> = (shortEdge - 1.0) * 0.5
    local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    local rRatio <const> = 255.0 / rMax
    local gRatio <const> = 255.0 / gMax
    local bRatio <const> = 255.0 / bMax

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

    -- Find main point of the triangle.
    local thetaActive <const> = hueActive * tau
    local thetaTri <const> = lockTriRot
        and active.angLockRadians
        or thetaActive - angOffsetRadians
    local xTri1 <const> = ringInEdge * math.cos(thetaTri)
    local yTri1 <const> = ringInEdge * math.sin(thetaTri)

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
    local xDiff2_3 <const> = xTri2 - xTri3
    local yDiff2_3 <const> = yTri2 - yTri3
    local xDiff1_3 <const> = xTri1 - xTri3
    local yDiff1_3 <const> = yTri1 - yTri3
    local xDiff3_2 <const> = xTri3 - xTri2
    local yDiff3_1 <const> = yTri3 - yTri1
    local xDiff1_2 <const> = xTri1 - xTri2
    local yDiff1_2 <const> = yTri1 - yTri2
    local bwDenom <const> = yDiff2_3 * xDiff1_3 + xDiff3_2 * yDiff1_3
    local bwDnmInv <const> = bwDenom ~= 0.0 and 1.0 / bwDenom or 0.0

    -- Cache methods used in while loop.
    local strpack <const> = string.pack
    local floor <const> = math.floor
    local atan <const> = math.atan

    local rBase <const>,
    gBase <const>,
    bBase <const> = hsvToRgb(hueActive, 1.0, 1.0)

    local packAlpha <const> = strpack("B B B B", 0, 0, 0, 0)
    local lenCanvas <const> = wCanvas * hCanvas

    if needsRingRepaint then
        ---@type string[]
        local ringByteStrs <const> = {}

        local i = 0
        while i < lenCanvas do
            local ringByteStr = packAlpha

            local yCanvas <const> = i // wCanvas
            local yDlt <const> = yCenter - yCanvas
            local yNrm <const> = yDlt * rCanvasInv

            local xCanvas <const> = i % wCanvas
            local xDlt <const> = xCanvas - xCenter
            local xNrm <const> = xDlt * rCanvasInv

            local sqMag <const> = xNrm * xNrm + yNrm * yNrm
            if sqMag >= sqRie and sqMag <= 1.0 then
                local angSigned <const> = atan(yNrm, xNrm)
                local angRotated <const> = angOffsetRadians + angSigned
                local angUnSigned <const> = angRotated % tau

                local hueWheel <const> = angUnSigned * oneTau
                local rWheel <const>,
                gWheel <const>,
                bWheel <const> = hsvToRgb(hueWheel, 1.0, 1.0)

                ringByteStr = strpack("B B B B",
                    floor(floor(rWheel * rMax + 0.5) * rRatio + 0.5),
                    floor(floor(gWheel * gMax + 0.5) * gRatio + 0.5),
                    floor(floor(bWheel * bMax + 0.5) * bRatio + 0.5),
                    255)
            end

            i = i + 1
            ringByteStrs[i] = ringByteStr
        end

        active.ringBytes = table.concat(ringByteStrs)
        active.triggerRingRepaint = false
    end

    if needsTriRepaint then
        ---@type string[]
        local triByteStrs <const> = {}

        local j = 0
        while j < lenCanvas do
            local triByteStr = packAlpha

            local yCanvas <const> = j // wCanvas
            local yDlt <const> = yCenter - yCanvas
            local yNrm <const> = yDlt * rCanvasInv

            local xCanvas <const> = j % wCanvas
            local xDlt <const> = xCanvas - xCenter
            local xNrm <const> = xDlt * rCanvasInv

            local sqMag <const> = xNrm * xNrm + yNrm * yNrm
            if sqMag < sqRie then
                local xbw <const> = xNrm - xTri3
                local ybw <const> = yNrm - yTri3
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

                    triByteStr = strpack("B B B B",
                        floor(floor(rTri * rMax + 0.5) * rRatio + 0.5),
                        floor(floor(gTri * gMax + 0.5) * gRatio + 0.5),
                        floor(floor(bTri * bMax + 0.5) * bRatio + 0.5),
                        255)
                end -- End ws in bounds.
            end

            j = j + 1
            triByteStrs[j] = triByteStr
        end

        active.triBytes = table.concat(triByteStrs)
        active.triggerTriRepaint = false
    end

    -- Draw picker canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvas,
        height = hCanvas,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }

    local imgRing <const> = Image(imgSpec)
    imgRing.bytes = active.ringBytes

    local imgTri <const> = Image(imgSpec)
    imgTri.bytes = active.triBytes

    local themeColors <const> = app.theme.color
    local bkgColor <const> = themeColors.window_face
    local imgComp <const> = Image(imgSpec)
    imgComp:clear(bkgColor)
    imgComp:drawImage(imgRing, Point(0, 0), 255, BlendMode.DST_OVER)
    imgComp:drawImage(imgTri, Point(0, 0), 255, BlendMode.DST_OVER)

    local drawRect <const> = Rectangle(0, 0, wCanvas, hCanvas)
    ctx:drawImage(imgComp, drawRect, drawRect)

    -- Draw reticle.
    local satActive <const> = isBackActive
        and active.satBack
        or active.satFore
    local valActive <const> = isBackActive
        and active.valBack
        or active.valFore

    local sv <const> = satActive * valActive
    local xRet01 <const> = xTri3
        + xDiff2_3 * valActive
        + xDiff1_2 * sv
    local yRet01 <const> = yTri3
        + yDiff2_3 * valActive
        + yDiff1_2 * sv

    local xReticle <const> = xCenter + xRet01 * rCanvas
    local yReticle <const> = yCenter - yRet01 * rCanvas
    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize * 0.5

    ctx.color = valActive < 0.5 and Color { r = 255, g = 255, b = 255, a = 255 }
        or Color { r = 0, g = 0, b = 0, a = 255 }
    ctx.strokeWidth = defaults.reticleStroke
    ctx:strokeRect(Rectangle(
        math.floor(xReticle - reticleHalf),
        math.floor(yReticle - reticleHalf),
        reticleSize, reticleSize))

    if lockTriRot then
        -- Draw hue reticle.
        local cosa <const> = math.cos(thetaActive - angOffsetRadians)
        local sina <const> = math.sin(thetaActive - angOffsetRadians)
        local ringInner = rCanvas * ringInEdge
        ctx.strokeWidth = 3
        ctx.color = Color { r = 255, g = 255, b = 255, a = 255 }
        ctx:moveTo(xCenter + ringInner * cosa, yCenter - ringInner * sina)
        ctx:lineTo(xCenter + rCanvas * cosa, yCenter - rCanvas * sina)
        ctx:stroke()
    end

    local swatchSize <const> = defaults.swatchSize
    local swatchMargin <const> = defaults.swatchMargin

    local offset <const> = swatchSize // 2
    local xSwatch <const> = wCanvas - swatchSize - swatchMargin
    local ySwatch <const> = hCanvas - swatchSize - swatchMargin

    -- Draw background color swatch.
    local r8Back <const> = math.floor(redBack * 255 + 0.5)
    local g8Back <const> = math.floor(greenBack * 255 + 0.5)
    local b8Back <const> = math.floor(blueBack * 255 + 0.5)

    ctx.color = Color { r = r8Back, g = g8Back, b = b8Back, a = 255 }
    ctx:fillRect(Rectangle(
        xSwatch - offset, ySwatch,
        swatchSize, swatchSize))

    -- Draw foreground color swatch.
    local r8Fore <const> = math.floor(redFore * 255 + 0.5)
    local g8Fore <const> = math.floor(greenFore * 255 + 0.5)
    local b8Fore <const> = math.floor(blueFore * 255 + 0.5)

    ctx.color = Color { r = r8Fore, g = g8Fore, b = b8Fore, a = 255 }
    ctx:fillRect(Rectangle(
        xSwatch, ySwatch - offset,
        swatchSize, swatchSize))

    -- If dialog is wide enough, draw diagnostic text.
    if (wCanvas - hCanvas) > defaults.textDisplayLimit
        and rCanvas > (swatchSize + swatchSize) then
        local textColor <const> = themeColors.text
        ctx.color = textColor

        local textSize <const> = ctx:measureText("E")
        local yIncr <const> = textSize.height + 4

        local hqActive <const> = isBackActive
            and active.hqBack
            or active.hqFore
        local sqActive <const> = isBackActive
            and active.sqBack
            or active.sqFore
        local vqActive <const> = isBackActive
            and active.vqBack
            or active.vqFore

        if vqActive > 0.0 and sqActive > 0.0 then
            ctx:fillText(string.format(
                "H: %.2f", hqActive * 360), 2, 2)
        end

        if vqActive > 0.0 then
            ctx:fillText(string.format(
                "S: %.2f%%", sqActive * 100), 2, 2 + yIncr)
        end

        ctx:fillText(string.format(
            "V: %.2f%%", vqActive * 100), 2, 2 + yIncr * 2)

        local redActive <const> = isBackActive
            and redBack
            or redFore
        local greenActive <const> = isBackActive
            and greenBack
            or greenFore
        local blueActive <const> = isBackActive
            and blueBack
            or blueFore

        local showAlphaBar <const> = active.showAlphaBar
        local alphaActive <const> = isBackActive
            and alphaBack
            or alphaFore

        ctx:fillText(string.format(
            "R: %.2f%%", redActive * 100), 2, 2 + yIncr * 4)
        ctx:fillText(string.format(
            "G: %.2f%%", greenActive * 100), 2, 2 + yIncr * 5)
        ctx:fillText(string.format(
            "B: %.2f%%", blueActive * 100), 2, 2 + yIncr * 6)
        if showAlphaBar then
            ctx:fillText(string.format(
                "A: %.2f%%", alphaActive * 100), 2, 2 + yIncr * 8)
        end

        local hexStr <const> = rgbToHexStr(redActive, greenActive, blueActive)
        local hexVertOffset <const> = showAlphaBar and 10 or 8
        ctx:fillText('#' .. hexStr,
            2, 2 + yIncr * hexVertOffset)
    end
end

---@param r01 number
---@param g01 number
---@param b01 number
---@param t01 number
---@param isBackActive boolean
local function updateQuantizedRgb(r01, g01, b01, t01, isBackActive)
    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    local rq <const> = math.floor(r01 * rMax + 0.5) / rMax
    local gq <const> = math.floor(g01 * gMax + 0.5) / gMax
    local bq <const> = math.floor(b01 * bMax + 0.5) / bMax

    active[isBackActive and "redBack" or "redFore"] = rq
    active[isBackActive and "greenBack" or "greenFore"] = gq
    active[isBackActive and "blueBack" or "blueFore"] = bq

    local hq <const>, sq <const>, vq <const> = rgbToHsv(rq, gq, bq)
    if vq > 0.0 then
        if sq > 0.0 then
            active[isBackActive and "hqBack" or "hqFore"] = hq
        end
        active[isBackActive and "sqBack" or "sqFore"] = sq
    end
    active[isBackActive and "vqBack" or "vqFore"] = vq

    local showAlphaBar <const> = active.showAlphaBar
    local r8 <const> = math.floor(rq * 255.0 + 0.5)
    local g8 <const> = math.floor(gq * 255.0 + 0.5)
    local b8 <const> = math.floor(bq * 255.0 + 0.5)
    local t8 <const> = showAlphaBar
        and math.floor(t01 * 255.0 + 0.5)
        or 255

    if isBackActive then
        app.command.SwitchColors()
        app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
        app.command.SwitchColors()
    else
        app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
    end
end

---@param ho number
---@param so number
---@param vo number
---@param isBackActive boolean
local function updateQuantizedHsv(ho, so, vo, isBackActive)
    local r01 <const>, g01 <const>, b01 <const> = hsvToRgb(ho, so, vo)
    local t01 <const> = isBackActive
        and active.alphaBack
        or active.alphaFore
    updateQuantizedRgb(r01, g01, b01, t01, isBackActive)
end

---@param hue number
local function updateFromHue(hue)
    local isBackActive <const> = active.isBackActive
    active[isBackActive and "hueBack" or "hueFore"] = hue

    local satWheel <const> = isBackActive
        and active.satBack
        or active.satFore
    local valWheel <const> = isBackActive
        and active.valBack
        or active.valFore
    updateQuantizedHsv(hue, satWheel, valWheel, isBackActive)
end

---@param sat number
local function updateFromSat(sat)
    local isBackActive <const> = active.isBackActive
    active[isBackActive and "satBack" or "satFore"] = sat

    local hueWheel <const> = isBackActive
        and active.hueBack
        or active.hueFore
    local valWheel <const> = isBackActive
        and active.valBack
        or active.valFore
    updateQuantizedHsv(hueWheel, sat, valWheel, isBackActive)
end

---@param val number
local function updateFromVal(val)
    local isBackActive <const> = active.isBackActive
    active[isBackActive and "valBack" or "valFore"] = val

    local hueWheel <const> = isBackActive
        and active.hueBack
        or active.hueFore
    local satWheel <const> = isBackActive
        and active.satBack
        or active.satFore
    updateQuantizedHsv(hueWheel, satWheel, val, isBackActive)
end

local function updateFromBitDepth()
    local r01Fore <const> = active.redFore
    local g01Fore <const> = active.greenFore
    local b01Fore <const> = active.blueFore
    local t01Fore <const> = active.alphaFore
    updateQuantizedRgb(r01Fore, g01Fore, b01Fore, t01Fore, false)

    local r01Back <const> = active.redBack
    local g01Back <const> = active.greenBack
    local b01Back <const> = active.blueBack
    local t01Back <const> = active.alphaBack
    updateQuantizedRgb(r01Back, g01Back, b01Back, t01Back, true)
end

---@param r8 integer
---@param g8 integer
---@param b8 integer
---@param t8 integer
---@param isBackActive boolean
local function updateFromAse(r8, g8, b8, t8, isBackActive)
    local r01 <const>,
    g01 <const>,
    b01 <const> = r8 / 255.0, g8 / 255.0, b8 / 255.0

    local ho <const>, so <const>, vo <const> = rgbToHsv(r01, g01, b01)
    if vo > 0.0 then
        if so > 0.0 then
            active[isBackActive and "hueBack" or "hueFore"] = ho
        end
        active[isBackActive and "satBack" or "satFore"] = so
    end
    active[isBackActive and "valBack" or "valFore"] = vo

    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    local rq <const> = math.floor((r01) * rMax + 0.5) / rMax
    local gq <const> = math.floor((g01) * gMax + 0.5) / gMax
    local bq <const> = math.floor((b01) * bMax + 0.5) / bMax

    active[isBackActive and "redBack" or "redFore"] = rq
    active[isBackActive and "greenBack" or "greenFore"] = gq
    active[isBackActive and "blueBack" or "blueFore"] = bq
    active[isBackActive and "alphaBack" or "alphaFore"] = t8 / 255.0

    local hq <const>, sq <const>, vq <const> = rgbToHsv(rq, gq, bq)
    if vq > 0.0 then
        if sq > 0.0 then
            active[isBackActive and "hqBack" or "hqFore"] = hq
        end
        active[isBackActive and "sqBack" or "sqFore"] = sq
    end
    active[isBackActive and "vqBack" or "vqFore"] = vq
end

local dlgMain <const> = Dialog {
    title = "Triangle Color Picker"
}

local dlgOptions <const> = Dialog {
    title = "Triangle Options",
    parent = dlgMain
}

local dlgHex <const> = Dialog {
    title = "Triangle Hex Code",
    parent = dlgMain
}

---@param r01 number
---@param g01 number
---@param b01 number
---@param t01 number
local function updateHexDisplay(r01, g01, b01, t01)
    local rMax <const> = active.rMax
    local gMax <const> = active.gMax
    local bMax <const> = active.bMax

    local r8 <const> = math.floor(r01 * 255 + 0.5)
    local g8 <const> = math.floor(g01 * 255 + 0.5)
    local b8 <const> = math.floor(b01 * 255 + 0.5)

    local rx <const> = math.floor(r01 * rMax + 0.5)
    local gx <const> = math.floor(g01 * gMax + 0.5)
    local bx <const> = math.floor(b01 * bMax + 0.5)

    local showAlphaBar <const> = active.showAlphaBar
    local t8 <const> = showAlphaBar
        and math.floor(t01 * 255.0 + 0.5)
        or 255

    dlgHex:modify {
        id = "rNote",
        text = string.format("R: %d / %d", rx, rMax)
    }

    dlgHex:modify {
        id = "gNote",
        text = string.format("G: %d / %d", gx, gMax)
    }

    dlgHex:modify {
        id = "bNote",
        text = string.format("B: %d / %d", bx, bMax)
    }

    dlgHex:modify { id = "previewColor", enabled = true }
    dlgHex:modify {
        id = "previewColor",
        color = Color { r = r8, g = g8, b = b8, a = t8 }
    }
    dlgHex:modify { id = "previewColor", enabled = false }
end

---@param event KeyEvent
local function onKeyDownMain(event)
    local isBackActive <const> = active.isBackActive
    local hueActive <const> = isBackActive
        and active.hueBack
        or active.hueFore
    local satActive <const> = isBackActive
        and active.satBack
        or active.satFore
    local valActive <const> = isBackActive
        and active.valBack
        or active.valFore

    local isShift = event.shiftKey
    local hueStep <const> = isShift
        and defaults.hueStep * defaults.shiftScalar
        or defaults.hueStep
    local satStep <const> = isShift
        and defaults.satStep * defaults.shiftScalar
        or defaults.satStep
    local valStep <const> = isShift
        and defaults.valStep * defaults.shiftScalar
        or defaults.valStep

    local eventCode <const> = event.code
    local isAlt <const> = event.altKey
    if eventCode == defaults.hueIncrKey then
        updateFromHue((hueActive + hueStep) % 1.0)
        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()
    elseif eventCode == defaults.hueDecrKey then
        updateFromHue((hueActive - hueStep) % 1.0)
        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()
    elseif isAlt and eventCode == defaults.satIncrKey then
        updateFromSat(math.min(math.max(satActive + satStep, 0.0), 1.0))
        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()
    elseif isAlt and eventCode == defaults.satDecrKey then
        updateFromSat(math.min(math.max(satActive - satStep, 0.0), 1.0))
        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()
    elseif eventCode == defaults.valIncrKey then
        updateFromVal(math.min(math.max(valActive + valStep, 0.0), 1.0))
        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()
    elseif eventCode == defaults.valDecrKey then
        updateFromVal(math.min(math.max(valActive - valStep, 0.0), 1.0))
        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()
    end
end

---@param event MouseEvent
local function onMouseMoveAlpha(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasAlpha
    local hCanvas <const> = active.hCanvasAlpha
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local xCanvas <const> = math.min(math.max(event.x, 0), wCanvas - 1)
    local xNrm <const> = xCanvas / (wCanvas - 1.0)

    -- Because the alpha bar and main canvas are separate, back
    -- would never be active unless you made a separate onMouseDownAlpha
    -- that set it as such.
    local isBackActive <const> = active.isBackActive
    active[isBackActive and "alphaBack" or "alphaFore"] = xNrm

    local r01 <const> = isBackActive and active.redBack or active.redFore
    local g01 <const> = isBackActive and active.greenBack or active.greenFore
    local b01 <const> = isBackActive and active.blueBack or active.blueFore
    local t01 <const> = isBackActive and active.alphaBack or active.alphaFore

    updateQuantizedRgb(r01, g01, b01, t01, isBackActive)
    if isBackActive then
        active.triggerAlphaRepaint = true
        active.triggerTriRepaint = true
    end
    dlgMain:repaint()
end

---@param event MouseEvent
local function onMouseMoveMain(event)
    if event.button == MouseButton.NONE then return end

    local isRing <const> = active.mouseDownRing
    local isTri <const> = active.mouseDownTri
    if (not isRing) and (not isTri) then return end

    local xMouseMove <const> = event.x
    local yMouseMove <const> = event.y

    local wCanvas <const> = active.wCanvasMain
    local hCanvas <const> = active.hCanvasMain
    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local rCanvas <const> = (shortEdge - 1.0) * 0.5
    local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

    local xDelta <const> = xMouseMove - xCenter
    local yDelta <const> = yCenter - yMouseMove

    local xNorm <const> = xDelta * rCanvasInv
    local yNorm <const> = yDelta * rCanvasInv

    if isRing then
        local angOffsetRadians <const> = active.angOffsetRadians
        local angSigned <const> = math.atan(yNorm, xNorm)
        local angRotated <const> = angSigned + angOffsetRadians
        local hwSigned = angRotated * oneTau
        if event.shiftKey then
            local shiftLevels <const> = defaults.shiftLevels
            hwSigned = math.floor(0.5 + hwSigned * shiftLevels) / shiftLevels
        end
        local hueWheel = hwSigned - math.floor(hwSigned)

        updateFromHue(hueWheel)
    elseif isTri then
        local ringInEdge <const> = active.ringInEdge
        local angOffsetRadians <const> = active.angOffsetRadians

        local isBackActive <const> = active.isBackActive
        local hueActive <const> = isBackActive
            and active.hueBack
            or active.hueFore

        -- Find main point of the triangle.
        local lockTriRot <const> = active.lockTriRot

        local xTri1 = ringInEdge * 1.0
        local yTri1 = ringInEdge * 0.0
        if lockTriRot then
            local angLockRadians <const> = active.angLockRadians
            xTri1 = ringInEdge * math.cos(angLockRadians)
            yTri1 = ringInEdge * math.sin(angLockRadians)
        else
            local thetaActive <const> = hueActive * tau
            local thetaTri <const> = thetaActive - angOffsetRadians
            xTri1 = ringInEdge * math.cos(thetaTri)
            yTri1 = ringInEdge * math.sin(thetaTri)
        end

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

        local rBase <const>, gBase <const>, bBase <const> = hsvToRgb(
            hueActive, 1.0, 1.0)

        local r01 <const> = (w1 * rBase + coeff) * wSumInv
        local g01 <const> = (w1 * gBase + coeff) * wSumInv
        local b01 <const> = (w1 * bBase + coeff) * wSumInv

        local _ <const>, so <const>, vo <const> = rgbToHsv(r01, g01, b01)
        if vo > 0.0 then
            active[isBackActive and "satBack" or "satFore"] = so
        end
        active[isBackActive and "valBack" or "valFore"] = vo

        local t01 <const> = isBackActive
            and active.alphaBack
            or active.alphaFore

        updateQuantizedRgb(r01, g01, b01, t01, isBackActive)
    end -- End is in tri or wheel.

    active.triggerTriRepaint = true
    active.triggerAlphaRepaint = true
    dlgMain:repaint()
end

---@param event MouseEvent
local function onMouseDownAlpha(event)
    local isRightClick <const> = event.button == MouseButton.RIGHT
    if isRightClick then
        active.isBackActive = true
    end
    onMouseMoveAlpha(event)
end

---@param event MouseEvent
local function onMouseDownMain(event)
    local xMouseDown <const> = event.x
    local yMouseDown <const> = event.y

    local ringInEdge <const> = active.ringInEdge
    local sqRie <const> = ringInEdge * ringInEdge

    local wCanvas <const> = active.wCanvasMain
    local hCanvas <const> = active.hCanvasMain
    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local rCanvas <const> = (shortEdge - 1.0) * 0.5
    local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

    local xDelta <const> = xMouseDown - xCenter
    local yDelta <const> = yCenter - yMouseDown

    local xNorm <const> = xDelta * rCanvasInv
    local yNorm <const> = yDelta * rCanvasInv

    local isRightClick <const> = event.button == MouseButton.RIGHT
    local sqMag <const> = xNorm * xNorm + yNorm * yNorm
    if (not active.mouseDownTri) and (sqMag >= sqRie and sqMag <= 1.0) then
        active.mouseDownRing = true
        if isRightClick then
            active.isBackActive = true
        end
    end

    if (not active.mouseDownRing) and (sqMag < sqRie) then
        active.mouseDownTri = true
        if isRightClick then
            active.isBackActive = true
        end
    end

    onMouseMoveMain(event)
end

---@param event MouseEvent
local function onMouseUpAlpha(event)
    if active.isBackActive then
        active.isBackActive = false
        active.triggerAlphaRepaint = true
        active.triggerTriRepaint = true
        dlgMain:repaint()
    end
end

---@param event MouseEvent
local function onMouseUpMain(event)
    local xMouseUp <const> = event.x
    local yMouseUp <const> = event.y

    local swatchSize <const> = defaults.swatchSize
    local swatchMargin <const> = defaults.swatchMargin
    local wCanvas <const> = active.wCanvasMain
    local hCanvas <const> = active.hCanvasMain

    local offset <const> = swatchSize // 2
    local xSwatch <const> = wCanvas - swatchSize - swatchMargin
    local ySwatch <const> = hCanvas - swatchSize - swatchMargin
    local offSizeSum <const> = offset + swatchSize - swatchMargin

    if xMouseUp >= xSwatch - offset
        and xMouseUp < xSwatch + offSizeSum
        and yMouseUp >= ySwatch - offset
        and yMouseUp < ySwatch + offSizeSum then
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

        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()

        local showAlphaBar <const> = active.showAlphaBar
        local fgt8 = 255
        local bgt8 = 255
        if showAlphaBar then
            fgt8 = math.floor(active.alphaFore * 255 + 0.5)
            bgt8 = math.floor(active.alphaBack * 255 + 0.5)
        end

        app.fgColor = Color {
            r = math.floor(active.redFore * 255 + 0.5),
            g = math.floor(active.greenFore * 255 + 0.5),
            b = math.floor(active.blueFore * 255 + 0.5),
            a = fgt8
        }
        app.command.SwitchColors()
        app.fgColor = Color {
            r = math.floor(active.redBack * 255 + 0.5),
            g = math.floor(active.greenBack * 255 + 0.5),
            b = math.floor(active.blueBack * 255 + 0.5),
            a = bgt8
        }
        app.command.SwitchColors()
    elseif active.isBackActive
        and (active.mouseDownRing
            or active.mouseDownTri) then
        active.isBackActive = false
        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true
        dlgMain:repaint()
    end

    active.mouseDownRing = false
    active.mouseDownTri = false
    active.isBackActive = false
end

-- region Main Dialog

dlgMain:canvas {
    id = "triCanvas",
    focus = true,
    width = defaults.wCanvasMain,
    height = defaults.hCanvasMain,
    onkeydown = onKeyDownMain,
    onmousedown = onMouseDownMain,
    onmousemove = onMouseMoveMain,
    onmouseup = onMouseUpMain,
    onpaint = onPaintMain,
    vexpand = true,
    hexpand = true,
}

dlgMain:newrow { always = false }

dlgMain:canvas {
    id = "alphaCanvas",
    focus = false,
    visible = defaults.showAlphaBar,
    width = defaults.wCanvas,
    height = defaults.hCanvasAlpha,
    onmousedown = onMouseDownAlpha,
    onmousemove = onMouseMoveAlpha,
    onmouseup = onMouseUpAlpha,
    onpaint = onPaintAlpha,
    hexpand = true,
    vexpand = false,
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "getForeButton",
    text = defaults.foreKey,
    focus = false,
    visible = defaults.showForeButton,
    onclick = function()
        if not app.sprite then return end

        local fgColor <const> = app.fgColor
        local r8fg <const> = fgColor.red
        local g8fg <const> = fgColor.green
        local b8fg <const> = fgColor.blue
        local t8fg <const> = fgColor.alpha
        -- It's poor form for a getter to change the property, but this
        -- is helpful when colors are chosen from palette index.
        -- app.fgColor = Color { r = r8fg, g = g8fg, b = b8fg, a = t8fg }

        updateFromAse(r8fg, g8fg, b8fg, t8fg, false)

        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true

        dlgMain:repaint()
    end
}

dlgMain:button {
    id = "getBackButton",
    text = defaults.backKey,
    focus = false,
    visible = defaults.showBackButton,
    onclick = function()
        if not app.sprite then return end

        app.command.SwitchColors()
        local bgColor <const> = app.fgColor
        local r8bg <const> = bgColor.red
        local g8bg <const> = bgColor.green
        local b8bg <const> = bgColor.blue
        local t8bg <const> = bgColor.alpha
        -- app.fgColor = Color { r = r8bg, g = g8bg, b = b8bg, a = t8bg }
        app.command.SwitchColors()

        updateFromAse(r8bg, g8bg, b8bg, t8bg, true)

        active.triggerTriRepaint = true
        active.triggerAlphaRepaint = true

        dlgMain:repaint()
    end
}

dlgMain:button {
    id = "palAppendButton",
    text = defaults.palAppendKey,
    focus = false,
    visible = defaults.showPalAppendButton,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local activeFrIdx = 1
        local activeFrObj <const> = app.frame
        if activeFrObj then
            activeFrIdx = activeFrObj.frameNumber
        end

        local palettes <const> = sprite.palettes
        local lenPalettes <const> = #palettes
        local palIdx <const> = (activeFrIdx >= 1
                and activeFrIdx <= lenPalettes)
            and activeFrIdx
            or 1
        local palette <const> = palettes[palIdx]
        local lenPalette <const> = #palette

        local showAlphaBar <const> = active.showAlphaBar
        local fgt8 = 255
        if showAlphaBar then
            fgt8 = math.floor(active.alphaFore * 255 + 0.5)
        end

        palette:resize(lenPalette + 1)
        palette:setColor(lenPalette, Color {
            r = math.floor(active.redFore * 255 + 0.5),
            g = math.floor(active.greenFore * 255 + 0.5),
            b = math.floor(active.blueFore * 255 + 0.5),
            a = fgt8
        })
        app.refresh()
    end
}

dlgMain:button {
    id = "sampleButton",
    text = defaults.sampleKey,
    focus = false,
    visible = defaults.showSampleButton,
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
        local alphaIndex <const> = spriteSpec.transparentColor
        local mouseSpec <const> = ImageSpec {
            width = 1,
            height = 1,
            colorMode = colorMode,
            transparentColor = alphaIndex
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
            local hasBkg <const> = sprite.backgroundLayer ~= nil
                and sprite.backgroundLayer.isVisible
            local palette <const> = sprite.palettes[1]
            local lenPalette <const> = #palette
            if (hasBkg or pixel ~= alphaIndex)
                and pixel >= 0 and pixel < lenPalette then
                local aseColor <const> = palette:getColor(pixel)
                r8 = aseColor.red
                g8 = aseColor.green
                b8 = aseColor.blue
                t8 = aseColor.alpha
            end
        elseif colorMode == ColorMode.GRAY then
            local v8 <const> = pixel & 0xff
            r8, g8, b8 = v8, v8, v8
            t8 = pixel >> 0x08 & 0xff
        else
            r8 = pixel & 0xff
            g8 = pixel >> 0x08 & 0xff
            b8 = pixel >> 0x10 & 0xff
            t8 = pixel >> 0x18 & 0xff
        end

        if t8 > 0 then
            updateFromAse(r8, g8, b8, t8, false)
            active.triggerTriRepaint = true
            active.triggerAlphaRepaint = true
            dlgMain:repaint()

            local showAlphaBar <const> = active.showAlphaBar
            local fgt8 <const> = showAlphaBar
                and math.floor(active.alphaFore * 255 + 0.5)
                or 255
            app.fgColor = Color {
                r = math.floor(active.redFore * 255 + 0.5),
                g = math.floor(active.greenFore * 255 + 0.5),
                b = math.floor(active.blueFore * 255 + 0.5),
                a = fgt8,
            }
        end
    end
}

dlgMain:button {
    id = "hexButton",
    text = defaults.hexKey,
    focus = false,
    visible = defaults.showHexButton,
    onclick = function()
        -- Whether the back is active is a hold down on mouse press,
        -- so it doesn't work well in this case.
        local r01 <const> = active.redFore
        local g01 <const> = active.greenFore
        local b01 <const> = active.blueFore
        local hexStr <const> = rgbToHexStr(r01, g01, b01)
        dlgHex:modify { id = "hexCode", text = hexStr }
        updateHexDisplay(r01, g01, b01, active.alphaFore)
        dlgHex:show { autoscrollbars = false, wait = true }
    end
}

dlgMain:button {
    id = "optionsButton",
    text = defaults.optionsKey,
    focus = false,
    visible = true,
    onclick = function()
        dlgOptions:show { autoscrollbars = true, wait = true }
    end
}

dlgMain:button {
    id = "exitMainButton",
    text = defaults.exitKey,
    focus = false,
    visible = defaults.showExitButton,
    onclick = function()
        dlgMain:close()
    end
}

-- endregion

-- region Hex Menu

dlgHex:color {
    id = "previewColor",
    color = Color { r = 0, g = 0, b = 0, a = 0 },
    focus = false,
    vexpand = true,
    hexpand = true,
    enabled = false,
}

dlgHex:newrow { always = false }

dlgHex:label { id = "rNote", text = "" }
dlgHex:newrow { always = false }
dlgHex:label { id = "gNote", text = "" }
dlgHex:newrow { always = false }
dlgHex:label { id = "bNote", text = "" }
dlgHex:newrow { always = false }

dlgHex:entry {
    id = "hexCode",
    text = defaults.hexCode,
    focus = true,
    onchange = function()
        local args <const> = dlgHex.data
        local hexCode <const> = args.hexCode --[[@as string]]
        local isValid <const>,
        r01 <const>,
        g01 <const>,
        b01 <const> = hexStrToRgb(hexCode)
        if not isValid then return end
        local t01 <const> = active.alphaFore
        updateHexDisplay(r01, g01, b01, t01)
    end
}

dlgHex:newrow { always = false }

dlgHex:button {
    id = "confirmHexButton",
    text = "&OK",
    focus = false,
    onclick = function()
        local args <const> = dlgHex.data
        local hexCode <const> = args.hexCode --[[@as string]]

        local isValid <const>,
        r01 <const>,
        g01 <const>,
        b01 <const> = hexStrToRgb(hexCode)

        if not isValid then return end

        active["redFore"] = r01
        active["greenFore"] = g01
        active["blueFore"] = b01

        local hq <const>, sq <const>, vq <const> = rgbToHsv(r01, g01, b01)
        if vq > 0.0 then
            if sq > 0.0 then
                active["hqFore"] = hq
                active["hueFore"] = hq
            end
            active["sqFore"] = sq
            active["satFore"] = sq
        end
        active["vqFore"] = vq
        active["valFore"] = vq

        active.triggerTriRepaint = true
        active.triggerRingRepaint = true
        active.triggerAlphaRepaint = true

        local showAlphaBar <const> = active.showAlphaBar
        local t01 <const> = active.alphaFore
        local r8 <const> = math.floor(r01 * 255.0 + 0.5)
        local g8 <const> = math.floor(g01 * 255.0 + 0.5)
        local b8 <const> = math.floor(b01 * 255.0 + 0.5)
        local t8 <const> = showAlphaBar
            and math.floor(t01 * 255.0 + 0.5)
            or 255

        app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }

        dlgMain:repaint()
        dlgHex:close()
    end
}

dlgHex:button {
    id = "exitHexButton",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlgHex:close()
    end
}

-- endregion

-- region Options Menu

dlgOptions:separator { text = "Ring" }

dlgOptions:slider {
    id = "degreesOffset",
    label = "Angle:",
    value = math.floor(-math.deg(
        defaults.angOffsetRadians) % 360 + 0.5),
    min = 0,
    max = 360,
    focus = false,
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "ringInEdge",
    label = "Weight:",
    value = math.floor(
        (1.0 - defaults.ringInEdge) * 100.0 + 0.5),
    min = 5,
    max = 33,
    focus = false
}

dlgOptions:separator { text = "Triangle" }

dlgOptions:check {
    id = "lockTriRot",
    label = "Angle:",
    text = "Lock",
    selected = defaults.lockTriRot,
    focus = false,
    hexpand = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local lockTriRot <const> = args.lockTriRot --[[@as boolean]]
        dlgOptions:modify { id = "lockOffset", visible = lockTriRot }
    end
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "lockOffset",
    value = math.floor(math.deg(defaults.angLockRadians) + 0.5),
    min = 0,
    max = 360,
    focus = false,
    visible = defaults.lockTriRot,
}

dlgOptions:separator { text = "Bit Depth" }

dlgOptions:slider {
    id = "rBitDepth",
    label = "Red:",
    value = defaults.rBitDepth,
    min = 1,
    max = 8,
    focus = false
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "gBitDepth",
    label = "Green:",
    value = defaults.gBitDepth,
    min = 1,
    max = 8,
    focus = false
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "bBitDepth",
    label = "Blue:",
    value = defaults.bBitDepth,
    min = 1,
    max = 8,
    focus = false
}

dlgOptions:separator { text = "Display" }

dlgOptions:check {
    id = "showForeButton",
    label = "Buttons:",
    text = "Fore",
    selected = defaults.showForeButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showBackButton",
    text = "Back",
    selected = defaults.showBackButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showExitButton",
    text = "X",
    selected = defaults.showExitButton,
    focus = false,
    hexpand = false,
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showPalAppendButton",
    text = "Append",
    selected = defaults.showPalAppendButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showSampleButton",
    text = "Sample",
    selected = defaults.showSampleButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showHexButton",
    text = "Hex",
    selected = defaults.showHexButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showAlphaBar",
    label = "Bars:",
    text = "Alpha",
    selected = defaults.showAlphaBar,
    focus = false,
    hexpand = false,
}

dlgOptions:newrow { always = false }

dlgOptions:button {
    id = "confirmOptionsButton",
    text = "&OK",
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data

        local degreesOffset <const> = args.degreesOffset --[[@as integer]]
        local ringInEdge100 <const> = args.ringInEdge --[[@as integer]]
        local lockTriRot <const> = args.lockTriRot --[[@as boolean]]
        local lockOffset <const> = args.lockOffset --[[@as integer]]

        local showFore <const> = args.showForeButton --[[@as boolean]]
        local showBack <const> = args.showBackButton --[[@as boolean]]
        local showExit <const> = args.showExitButton --[[@as boolean]]
        local showPalAppend <const> = args.showPalAppendButton --[[@as boolean]]
        local showSample <const> = args.showSampleButton --[[@as boolean]]
        local showHex <const> = args.showHexButton --[[@as boolean]]
        local showAlphaBar <const> = args.showAlphaBar --[[@as boolean]]

        local rBitDepth <const> = args.rBitDepth --[[@as integer]]
        local gBitDepth <const> = args.gBitDepth --[[@as integer]]
        local bBitDepth <const> = args.bBitDepth --[[@as integer]]

        active.angOffsetRadians = (-math.rad(degreesOffset)) % tau
        active.ringInEdge = 1.0 - ringInEdge100 * 0.01
        active.lockTriRot = lockTriRot
        active.angLockRadians = math.rad(lockOffset)
        active.showAlphaBar = showAlphaBar

        active.rBitDepth = rBitDepth
        active.gBitDepth = gBitDepth
        active.bBitDepth = bBitDepth

        active.rMax = (1 << rBitDepth) - 1.0
        active.gMax = (1 << gBitDepth) - 1.0
        active.bMax = (1 << bBitDepth) - 1.0

        -- For some changes aside from bit depth, maybe it'd be better to not
        -- change the color in the color bar?
        updateFromBitDepth()

        active.triggerTriRepaint = true
        active.triggerRingRepaint = true
        active.triggerAlphaRepaint = true

        dlgMain:repaint()

        dlgMain:modify { id = "getForeButton", visible = showFore }
        dlgMain:modify { id = "getBackButton", visible = showBack }
        dlgMain:modify { id = "palAppendButton", visible = showPalAppend }
        dlgMain:modify { id = "sampleButton", visible = showSample }
        dlgMain:modify { id = "hexButton", visible = showHex }
        dlgMain:modify { id = "exitMainButton", visible = showExit }
        dlgMain:modify { id = "alphaCanvas", visible = showAlphaBar }

        dlgOptions:close()
    end
}

dlgOptions:button {
    id = "exitOptionsButton",
    text = "&CANCEL",
    focus = true,
    onclick = function()
        dlgOptions:modify {
            id = "degreesOffset",
            value = math.floor(-math.deg(
                active.angOffsetRadians) % 360 + 0.5)
        }

        dlgOptions:modify {
            id = "ringInEdge",
            value = math.floor(
                (1.0 - active.ringInEdge) * 100.0 + 0.5)
        }

        dlgOptions:modify {
            id = "lockTriRot",
            selected = active.lockTriRot
        }

        dlgOptions:modify {
            id = "lockOffset",
            value = math.floor(math.deg(
                active.angLockRadians) + 0.5),
        }

        dlgOptions:modify { id = "rBitDepth", value = active.rBitDepth }
        dlgOptions:modify { id = "gBitDepth", value = active.gBitDepth }
        dlgOptions:modify { id = "bBitDepth", value = active.bBitDepth }

        dlgOptions:close()
    end
}

-- endregion

do
    local fgColor <const> = app.fgColor
    local r8fg <const> = fgColor.red
    local g8fg <const> = fgColor.green
    local b8fg <const> = fgColor.blue
    local t8fg <const> = fgColor.alpha
    updateFromAse(r8fg, g8fg, b8fg, t8fg, false)

    local r8bg = 255 - r8fg
    local g8bg = 255 - g8fg
    local b8bg = 255 - b8fg
    local t8bg = t8fg
    if app.sprite then
        app.command.SwitchColors()
        local bgColor <const> = app.fgColor
        r8bg = bgColor.red
        g8bg = bgColor.green
        b8bg = bgColor.blue
        t8bg = bgColor.alpha
        app.command.SwitchColors()
    end
    updateFromAse(r8bg, g8bg, b8bg, t8bg, true)

    dlgMain:repaint()
end

dlgMain:show {
    autoscrollbars = false,
    wait = false
}