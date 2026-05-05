--!strict
local Util = {}

function Util.Clamp(v: number, minv: number, maxv: number): number
    if v < minv then
        return minv
    end
    if v > maxv then
        return maxv
    end
    return v
end

function Util.Lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

function Util.RandomVectorInCone(dir: Vector3, spreadDegrees: number): Vector3
    local theta = math.rad(spreadDegrees)
    local u = math.random()
    local v = math.random()
    local angle = math.acos(1 - u + u * math.cos(theta))
    local phi = 2 * math.pi * v
    local axis1 = dir:Cross(Vector3.new(0, 1, 0))
    if axis1.Magnitude < 0.01 then
        axis1 = dir:Cross(Vector3.new(1, 0, 0))
    end
    axis1 = axis1.Unit
    local axis2 = dir:Cross(axis1).Unit
    local offset = axis1 * math.sin(angle) * math.cos(phi) + axis2 * math.sin(angle) * math.sin(phi) + dir * math.cos(angle)
    return offset.Unit
end

function Util.MakePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, anchored: boolean?): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = position
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = (anchored == nil) and true or anchored
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    return part
end

return Util
