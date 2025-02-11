-- We use ReturnCode ! Use it too ! (or fuck you)
global BS_SPIRITTOOLS_GENERAL = @"C:\spirittools\spirit-tools\General_Tools\"
filein (BS_SPIRITTOOLS_GENERAL + @"setup\_functions\ReturnCode\ReturnCode.ms")


-- Hop debut d'un code plus robuste que le Spline HD MD LD, 
-- sans limites, pense de maniere recursive
-----------------------------------------------------------


struct SpIKSetupLayer 
(
	-- Introspection
	_parentLayer = undefined, -- parent SplineIkSetupLayer layer

	-- origSPline
	_origSpline = undefined,

	-- Objects for this layer
	_spline,                  -- the spline constituting this layer
	_controllers,             -- the ctrls animating this layer
	_helpers,                 -- the helpers driving this.ctrls, constrained to ._parentLayer._spline
	
	-- Options for the layer
	_divisions  = 1,
	_layerIndex = 10,
	_layerName = "slay",
	_layerColor = (color 255 0 0),

	-- old expr, get rid of
	_previousSpline,


	isLeaf    = false, -- is this layer a leaf (end layer)
	isInitial = false, -- is this layer an initial one 


	fn _isSplineValid s:undefined = 
	(
		if s == undefined then s = this._spline
		(ReturnCode.new (superclassof s == shape) err_reason:"Invalid spline!" ok_reason:"Valid spline!")
	),

	fn divideSpline = 
	(
		for s=1 to (numSplines this._spline) do ( -- loop over each spline
			local numD = (numSegments this._previousSpline s) * (this._divisions + 1)
			subdivideSegment this._spline s 1 (numD-1)
		)
	),

	fn initSplineIkModifier = 
	(
		local spikMod = Spline_IK_Control()
		spikMod.linkTypes = 2
		addModifier this._spline (spikMod)
	),

	fn createControllers = 
	(
		this._spline.modifiers[1].createHelper (numknots this._spline 1)
		this._spline.modifiers[1].helper_size = (this._layerIndex * 10) - (this._layerIndex * 5)
		this._controllers = this._spline.modifiers[1].helper_list
	),


	fn createHelpers = 
	(
		-- Process controllers
		for z=1 to this._controllers.count do (
			
			local c = this._controllers[z]
			c.name = this._layerName + "_ctrl"
			c.wirecolor = this._layerColor

			--if z > 1 and z < sikLayer._controllers.count then (

				-- Create path helpers
				local pHelper = copy c
				pHelper.box = false
				pHelper.cross = true
				pHelper.name = stf.substitutestring pHelper.name "_ctrl" "_help"

				-- pathcst
				local pCst = Path_Constraint()
				pCst.appendTarget this._previousSpline 50.0
				pCst.follow = true
				--pCst.percent.controller = Bezier_Float()
				pHelper.position.controller = pCst
				deletekeys pCst #allkeys

				-- move path cst in place
				local perc = (((z-1.0) ) * 100.0) / (this._controllers.count-1.0) --* 100.0
				pCst.percent = perc


				c.parent = pHelper 
				append this._helpers pHelper
			--)
		)
	),


	on create do ()
)



struct SplineIkSetupCore 
(
	layerNames  = #(#ld, #md, #hd, #uhd, #uuhd, #uuuhd, #uuuuhd),
	layerColors = #((color 255 0 0), (color 255 255 0), (color 224 125 0), (color 224 192 160), (color 224 192 160), (color 224 192 255)),

	layerSplines = undefined,
	splineLayers = undefined,


	_layers = undefined,

	--- BASESPLINE
	baseSpline = undefined,
	fn validBaseSpline s:undefined = (
		if s == undefined then s = this.baseSpline
		(ReturnCode.new (superclassof s == shape) err_reason:"Invalid basespline!" ok_reason:"Basespline set")
	),

	fn setBaseSpline s = (
		local ret = this.validBaseSpline s:s
		if ret.ret then (this.baseSpline = s)
		ret
	),


	--- RIG LAYERS COUNT
	layersCount = 3,
	fn validateLayersCount i:undefined = (
		if i == undefined then i = this.layersCount
		ReturnCode.new (superclassof i == Number) err_reason:"setLayersCount() only takes integer." ok_reason:"LayersCount set"
	),
	fn setLayersCount i = (
		local ret = this.validateLayersCount i:i
		if ret.ret then (this.layersCount = i)
		ret
	),




	--- RIG LAYERS COUNT
	layerDivisions = 2,
	fn validateLayerDivisions i:undefined = (
		if i == undefined then i = this.layerDivisions
		local ret = ReturnCode.new (superclassof i == Number) err_reason:"validateLayerDivisions() only takes integer." ok_reason:"LayerDivisions set"

		ret
	),	
	fn setLayerDivisions i = (
		local ret = this.validateLayerDivisions i:i
		if ret.ret then (this.layerDivisions = i)
		ret
	),




	fn processLayers = (

		-- Create layers
		for i=2 to this.layersCount do (

			-- Get new layer infos
			local layName = this.layerNames[i] as string
			if /*(stf.isMax2018())*/ true then (layName = tolower layName)
			local layColor = this.layerColors[i]  

			-- Make new spline out of the previous one
			local newSpline = copy this._layers[i-1]._origSpline
			newSpline.name = stf.substitutestring this._layers[i-1]._spline.name this.layerNames[i-1] layName
			newSpline.wirecolor = layColor

			-- Create the new spline layer
			local sikLayer = (SpIKSetupLayer \
										_origSpline:this._layers[i-1]._origSpline \
										_divisions:this.layerDivisions \
										_layerColor:layColor \
										_layerName:layName \
										_layerIndex:(i) \
										_spline:newSpline \
										_previousSpline:this._layers[i-1]._spline \
										_helpers:#())

			-- Subdivide spline based on previous one
			sikLayer.divideSpline()

			-- init spline_ik_control mod
			sikLayer.initSplineIkModifier()

			-- Create controllers
			sikLayer.createControllers()

			-- Process controllers
			sikLayer.createHelpers()

			-- Store the layer
			append this._layers sikLayer
		)
	),



	fn rig = (
		local ret = this.validBaseSpline()
		if ret.ret then (
			
			ret  = this.validateLayersCount()
			if ret.ret then (

				ret = this.validateLayerDivisions()
				if ret.ret then (

					this.processLayers()
				)
			)
		)
		ret
	),




	--- INIT
	fn init s layersCount:3 layerDivisions:1 = 
	(
		local ret = this.setBaseSpline s
		if ret.ret then (
			
			ret = this.setLayersCount layersCount
			if ret.ret then (

				ret = this.setLayerDivisions layerDivisions
				if ret.ret then (

					-- do last objects inits
					this.layerSplines = #(this.baseSpline)
					this.splineLayers = #(SpIKSetupLayer _spline:this.baseSpline _helpers:#())


					-- Init the _layers with an initial one based on the userspline
					this._layers = #(
						(
							SpIKSetupLayer _divisions:this.layerDivisions \
						 				   _layerColor:layColor \
						 				   _layerName:layName \
						 				   _layerIndex:(i) \
						 				   _spline:s \
						 				   _previousSpline:s \
						 				   _helpers:#() \
						 				   _origSpline:s
						 )
					)
				)
			)
		)
		ret
	),




	on create do (
		-- Adjust counts..
		for i = 1 to 10 do (
			this.layerColors = this.layerColors + #((color 255 i i))
			this.layerNames  = this.layerNames + #(("u") + (this.layerNames[this.layerNames.count] as string))
		)
	)
)

sisc = SplineIkSetupCore()
retinit = sisc.init $Line001 layersCount:4 layerDivisions:2
if retinit.ret then (
	sisc.rig()
)else(
	retinit
)