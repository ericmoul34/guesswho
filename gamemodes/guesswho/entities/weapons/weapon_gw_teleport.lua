AddCSLuaFile()

SWEP.Base = "weapon_gwbase"
SWEP.Name = "Teleport"

SWEP.AbilityDuration = 1.5
SWEP.AbilityRange = 1500
SWEP.AbilityDescription = "Teleports you to the position indicated by the glowing playermodel.\nTeleportation occurs after a $AbilityDuration second delay. The maximum teleport range is $AbilityRange."

function SWEP:SetupDataTables()
	self:NetworkVar("Vector", 0, "CalculatedTeleportDestination")
	self:NetworkVar("Bool", 0, "CalculatedTeleportDestinationValid")
end

function SWEP:AbilityCreated()
	self.ClientCalculatedTeleportDestination = Vector(0, 0, 0)
	
	if CLIENT then
		self.destinationModel = ClientsideModel(self.Owner:GetModel(), RENDERGROUP_TRANSLUCENT)
		self.destinationModel:SetupBones()
		self.destinationModel:SetColor(Color( 255, 255, 255, 220))
		self.destinationModel:SetRenderMode(RENDERMODE_TRANSALPHA)
		self.haloColor = Color(0, 255, 0)
		self.haloHookName = "gwTeleportHalo" .. self:EntIndex()
		hook.Add("PreDrawHalos", self.haloHookName, function()
			halo.Add({self.destinationModel}, self.haloColor, 2, 2, 3, true, true)
		end)
	end
end

function SWEP:Ability()
	local ply = self.Owner

	if self:GetCalculatedTeleportDestinationValid() then
		if SERVER then ply:ApplyStun(2) end

		local fadeOut = EffectData()
		fadeOut:SetEntity(ply)
		fadeOut:SetMagnitude(self.AbilityDuration)
		fadeOut:SetScale(-1)
		fadeOut:SetSurfaceProp(-1)
		util.Effect("gw_teleport_fade", fadeOut)
	
		self:AbilityTimerIfValidPlayerAndAlive(self.AbilityDuration + FrameTime() * 2, 1, true, function()
				local fadeIn = EffectData()
				fadeIn:SetEntity(ply)
				fadeIn:SetMagnitude(self.AbilityDuration)
				fadeIn:SetScale(1)
				fadeIn:SetSurfaceProp(1)
				util.Effect("gw_teleport_fade", fadeIn)
				if SERVER then
					ply:SetPos(self:GetCalculatedTeleportDestination())
				end
			end
		)
	else
		return true
	end
end

function SWEP:Think()
	if SERVER then
		local isValid, pos = self:CalcTeleportDestination()
		self:SetCalculatedTeleportDestinationValid(isValid)
		self:SetCalculatedTeleportDestination(pos)
	end
end

function SWEP:DrawHUD()
	if self:Clip2() <= 0 then
		self:RemoveDestinationModel()
		return
	end

	if self.destinationModel ~= self.Owner:GetModel() then
		self.destinationModel:SetModel(self.Owner:GetModel())
	end

	local teleportDestination = self:GetCalculatedTeleportDestination()
	local teleportDestinationValid = self:GetCalculatedTeleportDestinationValid()

	self.destinationModel:SetColor(Color( 255, 255, 255, 180))

	if teleportDestinationValid then
		self.haloColor = Color(0, 255, 0)
	else
		self.haloColor = Color(255, 0, 0)
	end

	self.ClientCalculatedTeleportDestination = LerpVector(math.Clamp(FrameTime() * 60, 0, 1), self.ClientCalculatedTeleportDestination, teleportDestination)

	self.destinationModel:SetAngles(Angle(0, self.Owner:GetAngles().yaw, 0))
	self.destinationModel:SetPos(self.ClientCalculatedTeleportDestination)
end

function SWEP:GetTeleportTraceStart()
	return self.Owner:GetPos() + Vector(0, 0, 100)
end

function SWEP:CalcTeleportDestination()
	local forwardWithoutZ = self.Owner:GetForward()
	forwardWithoutZ.z = 0

	local eyeTraceStart = self:GetTeleportTraceStart()

	local aimVector = self.Owner:GetAimVector()

	local trace = util.TraceLine({
		start = eyeTraceStart,
		endpos = eyeTraceStart + aimVector * self.AbilityRange,
		mask = MASK_PLAYERSOLID,
	})

	local secondTraceStart = trace.HitPos - (trace.Normal * 64)

	local secondTrace = util.TraceLine({
		start = secondTraceStart,
		endpos = secondTraceStart - Vector(0, 0, 1000),
		mask = MASK_PLAYERSOLID,
	})

	local navArea = navmesh.GetNearestNavArea(secondTrace.HitPos + secondTrace.HitNormal, false, 10000, true)
	if IsValid(navArea) then
		local navAreaClosestPoint = navArea:GetClosestPointOnArea(secondTrace.HitPos) + Vector(0, 0, 5)

		local hullTrace = util.TraceEntity(
			{
				start= navAreaClosestPoint,
				endpos= navAreaClosestPoint,
				mask=MASK_SOLID
			},
			self.Owner
		)

		if hullTrace.Hit then
			return false, navAreaClosestPoint
		end
	
		return true, navAreaClosestPoint
	end

	return false, trace.HitPos
end

function SWEP:RemoveDestinationModel()
	if self.destinationModel then
		SafeRemoveEntity(self.destinationModel)
		self.destinationModel = nil
	end
	hook.Remove("PreDrawHalos", self.haloHookName)
end

function SWEP:AbilityCleanup()
	if IsValid(self.Owner) then
		self.Owner.RenderOverride = nil
	end
	self:RemoveDestinationModel()
end
