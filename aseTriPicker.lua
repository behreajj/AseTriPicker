local defaults <const> = {
    wCanvas = 200,
    hCanvas = 200,
    xCenter = 100,
    yCenter = 100,
    ringInEdge = 0.9,
    angOffset = 0.5235987755983,
    hue = 0.0,
    sat = 1.0,
    val = 1.0,
    alpha = 1.0,
    textDisplayLimit = 50,
    swatchSize = 16,
    lrKeyIncr = 1.0 / 1080.0,
    retEps = 0.015,
    shiftLevels = 24,
    rLevels = 8,
    gLevels = 8,
    bLevels = 8
}

local active <const> = {
    wCanvas = defaults.wCanvas,
    hCanvas = defaults.hCanvas,

    hueFore = defaults.hue,
    satFore = defaults.sat,
    valFore = defaults.val,
    alphaFore = defaults.alpha,

    hueBack = defaults.hue,
    satBack = defaults.sat,
    valBack = defaults.val,
    alphaBack = defaults.alpha,

    fgBgFlag = 0,
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

    -- TODO: Simplify this by returning the chroma as well as the sat?
    -- That might be the missing difference between sat and uv coords below?
    -- See figure https://www.wikiwand.com/en/HSL_and_HSV#Media/File:Hsl-hsv_saturation-lightness_slices.svg
    return hue / 6.0, chroma / mx, mx
end

-- TODO: These need to be set to levels.
local initFgColor <const> = Color(app.fgColor)
active.hueFore, active.satFore, active.valFore = rgbToHsv(
    initFgColor.red / 255.0,
    initFgColor.green / 255.0,
    initFgColor.blue / 255.0)
active.alphaFore = initFgColor.alpha / 255.0

-- TODO: These need to be set to levels.
local initBgColor <const> = Color(app.bgColor)
active.hueBack, active.satBack, active.valBack = rgbToHsv(
    initBgColor.red / 255.0,
    initBgColor.green / 255.0,
    initBgColor.blue / 255.0)
active.alphaBack = initBgColor.alpha / 255.0

local dlg = Dialog { title = "Color Picker" }

dlg:canvas {
    id = "triCanvas",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvas,
    onmousedown = function(event)
        local xMouseDown <const> = event.x
        local yMouseDown <const> = event.y

        local ringInEdge <const> = defaults.ringInEdge
        local sqRie <const> = ringInEdge * ringInEdge

        local wCanvas <const> = active.wCanvas
        local hCanvas <const> = active.hCanvas
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
                active.fgBgFlag = 1
            end
        end

        if (not active.mouseDownRing) and (sqMag < sqRie) then
            active.mouseDownTri = true
            if event.button == MouseButton.RIGHT then
                active.fgBgFlag = 1
            end
        end
    end,
    onmouseup = function(event)
        local xMouseUp <const> = event.x
        local yMouseUp <const> = event.y

        active.mouseDownRing = false
        active.mouseDownTri = false
        active.fgBgFlag = 0

        local swatchSize <const> = defaults.swatchSize
        local offset <const> = swatchSize // 2
        local hCanvas <const> = active.hCanvas
        if xMouseUp >= 0 and xMouseUp < offset + swatchSize
            and yMouseUp >= hCanvas - swatchSize - 1 - offset
            and yMouseUp < hCanvas then
            local hTemp <const> = active.hueBack
            local sTemp <const> = active.satBack
            local vTemp <const> = active.valBack
            local aTemp <const> = active.alphaBack

            active.hueBack = active.hueFore
            active.satBack = active.satFore
            active.valBack = active.valFore
            active.alphaBack = active.alphaFore

            active.hueFore = hTemp
            active.satFore = sTemp
            active.valFore = vTemp
            active.alphaFore = aTemp

            dlg:repaint()
            app.command.SwitchColors()
        end
    end,
    onmousemove = function(event)
        local xMouseMove <const> = event.x
        local yMouseMove <const> = event.y

        if event.button ~= MouseButton.NONE
            and (active.mouseDownRing or active.mouseDownTri) then
            local wCanvas <const> = active.wCanvas
            local hCanvas <const> = active.hCanvas
            local xCenter <const> = wCanvas * 0.5
            local yCenter <const> = hCanvas * 0.5
            local shortEdge <const> = math.min(wCanvas, hCanvas)
            local rCanvas <const> = (shortEdge - 1.0) * 0.5
            local rCanvasInv <const> = rCanvas ~= 0.0 and 1.0 / rCanvas or 0.0

            local xDelta <const> = xMouseMove - xCenter
            local yDelta <const> = yCenter - yMouseMove

            local xNorm <const> = xDelta * rCanvasInv
            local yNorm <const> = yDelta * rCanvasInv

            if active.mouseDownRing then
                local angOffset <const> = defaults.angOffset
                local oneTau <const> = 0.1591549430919
                local angSigned <const> = math.atan(yNorm, xNorm)

                local hwSigned = (angSigned + angOffset) * oneTau
                -- if event.shiftKey then
                --     local shiftLevels <const> = defaults.shiftLevels
                --     hwSigned = math.floor(0.5 + hwSigned * shiftLevels) / shiftLevels
                -- end

                local hueWheel = hwSigned - math.floor(hwSigned)

                local isBack <const> = active.fgBgFlag == 1
                local satWheel <const> = isBack
                    and active.satBack
                    or active.satFore
                local valWheel <const> = isBack
                    and active.valBack
                    or active.valFore
                local alphaWheel <const> = isBack
                    and active.alphaBack
                    or active.alphaFore

                local rf <const>, gf <const>, bf <const> = hsvToRgb(hueWheel, satWheel, valWheel)

                local args <const> = dlg.data
                local rLevels <const> = args.rLevels or defaults.rLevels --[[@as integer]]
                local gLevels <const> = args.gLevels or defaults.gLevels --[[@as integer]]
                local bLevels <const> = args.bLevels or defaults.bLevels --[[@as integer]]

                local rMax <const> = (1 << rLevels) - 1.0
                local gMax <const> = (1 << gLevels) - 1.0
                local bMax <const> = (1 << bLevels) - 1.0

                local rf2 <const> = math.floor(rf * rMax + 0.5) / rMax
                local gf2 <const> = math.floor(gf * gMax + 0.5) / gMax
                local bf2 <const> = math.floor(bf * bMax + 0.5) / bMax

                local hq <const>, sq <const>, vq <const> = rgbToHsv(rf2, gf2, bf2)

                if isBack then
                    active.hueBack = hueWheel
                    active.satBack = sq
                    active.valBack = vq

                    app.command.SwitchColors()
                    app.fgColor = Color {
                        hue = hq * 360.0,
                        saturation = sq,
                        value = vq,
                        alpha = math.floor(alphaWheel * 255.0 + 0.5)
                    }
                    app.command.SwitchColors()
                else
                    active.hueFore = hueWheel
                    active.satFore = sq
                    active.valFore = vq

                    app.fgColor = Color {
                        hue = hq * 360.0,
                        saturation = sq,
                        value = vq,
                        alpha = math.floor(alphaWheel * 255.0 + 0.5)
                    }
                end

                dlg:repaint()
            elseif active.mouseDownTri then
                local ringInEdge <const> = defaults.ringInEdge
                local angOffset <const> = defaults.angOffset
                local tau <const> = 6.2831853071796
                local sqrt3_2 <const> = 0.86602540378444

                local hActive = 0.0
                if active.fgBgFlag == 1 then
                    hActive = active.hueBack
                else
                    hActive = active.hueFore
                end

                -- Find main point of the triangle.
                local hActiveTheta <const> = (hActive * tau) - angOffset
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

                -- TODO: Any way to optimize these? Maybe by multiplying
                -- bwDnmInv times xbw and ybw?
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

                local rBase <const>, gBase <const>, bBase <const> = hsvToRgb(hActive, 1.0, 1.0)

                local rf <const> = (w1 * rBase + coeff) * wSumInv
                local gf <const> = (w1 * gBase + coeff) * wSumInv
                local bf <const> = (w1 * bBase + coeff) * wSumInv

                local args <const> = dlg.data
                local rLevels <const> = args.rLevels or defaults.rLevels --[[@as integer]]
                local gLevels <const> = args.gLevels or defaults.gLevels --[[@as integer]]
                local bLevels <const> = args.bLevels or defaults.bLevels --[[@as integer]]

                local rMax <const> = (1 << rLevels) - 1.0
                local gMax <const> = (1 << gLevels) - 1.0
                local bMax <const> = (1 << bLevels) - 1.0

                local rf2 <const> = math.floor(rf * rMax + 0.5) / rMax
                local gf2 <const> = math.floor(gf * gMax + 0.5) / gMax
                local bf2 <const> = math.floor(bf * bMax + 0.5) / bMax

                local hq <const>, sq <const>, vq <const> = rgbToHsv(rf2, gf2, bf2)

                if active.fgBgFlag == 1 then
                    active.satBack = sq
                    active.valBack = vq

                    app.command.SwitchColors()
                    app.fgColor = Color {
                        hue = hq * 360.0,
                        saturation = sq,
                        value = vq,
                        alpha = math.floor(active.alphaBack * 255.0 + 0.5)
                    }
                    app.command.SwitchColors()
                else
                    active.satFore = sq
                    active.valFore = vq

                    app.fgColor = Color {
                        hue = hq * 360.0,
                        saturation = sq,
                        value = vq,
                        alpha = math.floor(active.alphaFore * 255.0 + 0.5)
                    }
                end

                dlg:repaint()
            end
        end
    end,
    onpaint = function(event)
        local angOffset <const> = defaults.angOffset
        local ringInEdge <const> = defaults.ringInEdge

        local sqRie <const> = ringInEdge * ringInEdge
        local tau <const> = 6.2831853071796
        local oneTau <const> = 0.1591549430919
        local sqrt3_2 <const> = 0.86602540378444

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

        local args <const> = dlg.data
        local rLevels <const> = args.rLevels or defaults.rLevels --[[@as integer]]
        local gLevels <const> = args.gLevels or defaults.gLevels --[[@as integer]]
        local bLevels <const> = args.bLevels or defaults.bLevels --[[@as integer]]

        local rMax <const> = (1 << rLevels) - 1.0
        local gMax <const> = (1 << gLevels) - 1.0
        local bMax <const> = (1 << bLevels) - 1.0

        local rRatio <const> = 255.0 / rMax
        local gRatio <const> = 255.0 / gMax
        local bRatio <const> = 255.0 / bMax

        active.wCanvas = wCanvas
        active.hCanvas = hCanvas

        local hActive = 0.0
        local sActive = 0.0
        local vActive = 0.0
        local tActive = 0.0

        if active.fgBgFlag == 1 then
            hActive = active.hueBack
            sActive = active.satBack
            vActive = active.valBack
            tActive = active.alphaBack
        else
            hActive = active.hueFore
            sActive = active.satFore
            vActive = active.valFore
            tActive = active.alphaFore
        end

        -- Find main point of the triangle.
        local hActiveTheta <const> = (hActive * tau) - angOffset
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
        -- Cf. https://codeplea.com/triangular-interpolation
        local yDiff2_3 <const> = yTri2 - yTri3
        local xDiff1_3 <const> = xTri1 - xTri3
        local xDiff3_2 <const> = xTri3 - xTri2
        local yDiff1_3 <const> = yTri1 - yTri3
        local yDiff3_1 <const> = yTri3 - yTri1
        local bwDenom <const> = yDiff2_3 * xDiff1_3 + xDiff3_2 * yDiff1_3
        local bwDnmInv <const> = bwDenom ~= 0.0 and 1.0 / bwDenom or 0.0
        local rBase <const>, gBase <const>, bBase <const> = hsvToRgb(hActive, 1.0, 1.0)

        -- Cache method used in while loop.
        local strpack <const> = string.pack
        local floor <const> = math.floor
        local atan <const> = math.atan

        local themeColors <const> = app.theme.color
        local bkgColor <const> = themeColors.window_face
        local textColor <const> = themeColors.text

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
                local angSigned <const> = angOffset + atan(yNorm, xNorm)
                local hueWheel <const> = (angSigned % tau) * oneTau

                local rf <const>, gf <const>, bf <const> = hsvToRgb(hueWheel, 1.0, 1.0)

                local r8 = floor(floor(rf * rMax + 0.5) * rRatio + 0.5)
                local g8 = floor(floor(gf * gMax + 0.5) * gRatio + 0.5)
                local b8 = floor(floor(bf * bMax + 0.5) * bRatio + 0.5)

                byteStr = strpack("B B B B", r8, g8, b8, 255)
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

                    local rf <const> = (w1 * rBase + coeff) * wSumInv
                    local gf <const> = (w1 * gBase + coeff) * wSumInv
                    local bf <const> = (w1 * bBase + coeff) * wSumInv

                    local r8 = floor(floor(rf * rMax + 0.5) * rRatio + 0.5)
                    local g8 = floor(floor(gf * gMax + 0.5) * gRatio + 0.5)
                    local b8 = floor(floor(bf * bMax + 0.5) * bRatio + 0.5)

                    byteStr = strpack("B B B B", r8, g8, b8, 255)
                end
            end

            i = i + 1
            byteStrs[i] = byteStr
        end

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
            hue = active.hueBack * 360,
            saturation = active.satBack,
            value = active.valBack,
            alpha = 255
        }
        ctx:fillRect(Rectangle(
            offset, hCanvas - swatchSize - 1,
            swatchSize, swatchSize))

        -- Draw foreground color swatch.
        ctx.color = Color {
            hue = active.hueFore * 360,
            saturation = active.satFore,
            value = active.valFore,
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

            ctx.color = textColor

            if vActive > 0.0 then
                if sActive > 0.0 then
                    -- TODO: This is no longer accurate because hue wheel
                    -- is not quantized.
                    ctx:fillText(string.format(
                        "H: %.2f", hActive * 360), 2, 2)
                end
                ctx:fillText(string.format(
                    "S: %.2f%%", sActive * 100), 2, 2 + yIncr)
            end
            ctx:fillText(string.format(
                "V: %.2f%%", vActive * 100), 2, 2 + yIncr * 2)

            local rf <const>, gf <const>, bf <const> = hsvToRgb(
                hActive, sActive, vActive)

            local rf2 <const> = math.floor(rf * rMax + 0.5) / rMax
            local gf2 <const> = math.floor(gf * gMax + 0.5) / gMax
            local bf2 <const> = math.floor(bf * bMax + 0.5) / bMax

            ctx:fillText(string.format(
                "R: %.2f%%", rf2 * 100), 2, 2 + yIncr * 4)
            ctx:fillText(string.format(
                "G: %.2f%%", gf2 * 100), 2, 2 + yIncr * 5)
            ctx:fillText(string.format(
                "B: %.2f%%", bf2 * 100), 2, 2 + yIncr * 6)

            ctx:fillText(string.format(
                "A: %.2f%%", tActive * 100), 2, 2 + yIncr * 8)
            local r8 <const> = floor(rf2 * 255 + 0.5)
            local g8 <const> = floor(gf2 * 255 + 0.5)
            local b8 <const> = floor(bf2 * 255 + 0.5)

            ctx:fillText(string.format(
                "#%06x", r8 << 0x10|g8 << 0x08|b8), 2, 2 + yIncr * 10)
        end
    end,
}

dlg:newrow { always = false }

dlg:slider {
    id = "rLevels",
    value = defaults.rLevels,
    min = 1,
    max = 8,
    focus = false,
    onchange = function() dlg:repaint() end
}

dlg:slider {
    id = "gLevels",
    value = defaults.gLevels,
    min = 1,
    max = 8,
    focus = false,
    onchange = function() dlg:repaint() end
}

dlg:slider {
    id = "bLevels",
    value = defaults.bLevels,
    min = 1,
    max = 8,
    focus = false,
    onchange = function() dlg:repaint() end
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

        local args <const> = dlg.data
        local rLevels <const> = args.rLevels or defaults.rLevels --[[@as integer]]
        local gLevels <const> = args.gLevels or defaults.gLevels --[[@as integer]]
        local bLevels <const> = args.bLevels or defaults.bLevels --[[@as integer]]

        local rMax <const> = (1 << rLevels) - 1.0
        local gMax <const> = (1 << gLevels) - 1.0
        local bMax <const> = (1 << bLevels) - 1.0

        local rf <const> = math.floor((r8 / 255.0) * rMax + 0.5) / rMax
        local gf <const> = math.floor((g8 / 255.0) * gMax + 0.5) / gMax
        local bf <const> = math.floor((b8 / 255.0) * bMax + 0.5) / bMax

        active.hueFore, active.satFore, active.valFore = rgbToHsv(
            rf, gf, bf)
        active.alphaFore = t8 / 255.0

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

        local args <const> = dlg.data
        local rLevels <const> = args.rLevels or defaults.rLevels --[[@as integer]]
        local gLevels <const> = args.gLevels or defaults.gLevels --[[@as integer]]
        local bLevels <const> = args.bLevels or defaults.bLevels --[[@as integer]]

        local rMax <const> = (1 << rLevels) - 1.0
        local gMax <const> = (1 << gLevels) - 1.0
        local bMax <const> = (1 << bLevels) - 1.0

        local rf <const> = math.floor((r8 / 255.0) * rMax + 0.5) / rMax
        local gf <const> = math.floor((g8 / 255.0) * gMax + 0.5) / gMax
        local bf <const> = math.floor((b8 / 255.0) * bMax + 0.5) / bMax

        app.command.SwitchColors()
        active.hueBack, active.satBack, active.valBack = rgbToHsv(
            rf, gf, bf)
        active.alphaBack = t8 / 255.0

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
    autoscrollbars = true,
    wait = false
}