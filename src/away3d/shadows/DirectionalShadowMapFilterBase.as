package away3d.shadows
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.errors.AbstractMethodError;
	import away3d.lights.DirectionalLight;

	import flash.display3D.Context3DProgramType;

	use namespace arcane;

	public class DirectionalShadowMapFilterBase
	{
		protected var _data : Vector.<Number>;
		private var _numConstantRegisters : uint;
		private var _constantRegisterOffsets : Vector.<uint>;
		private var _needsProjectionScale : Boolean;

		public function DirectionalShadowMapFilterBase(numConstantRegisters : uint = 2, needsProjectionScale : Boolean = false)
		{
			_numConstantRegisters = numConstantRegisters;
			_constantRegisterOffsets = new Vector.<uint>(4, true);
			_data = new Vector.<Number>(numConstantRegisters*4, true);
			_data[0] = 1.0;
			_data[1] = 1.0/255.0;
			_data[2] = 1.0/65025.0;
			_data[3] = 1.0/16581375.0;
			_data[4] = -.002;
			_needsProjectionScale = needsProjectionScale;
		}

		arcane function get needsProjectionScale() : Boolean
		{
			return _needsProjectionScale;
		}

		public function get depthOffset() : Number
		{
			return -_data[4];
		}

		public function set depthOffset(value : Number) : void
		{
			_data[4] = -value;
		}

		public function getConstantRegisterOffset(numCascades : uint) : uint
		{
			return _constantRegisterOffsets[numCascades-1];
		}

		public function setConstantRegisterOffset(numCascades : uint, value : uint) : void
		{
			_constantRegisterOffsets[numCascades-1] = value;
		}

		protected function getConstantRegister(numCascades : uint, index : uint) : String
		{
			if (index > _numConstantRegisters) throw new Error("Overflow! You need to increase the numConstantRegisters passed in the ShadowMapFilterBase constructor");

			return "fc"+(_constantRegisterOffsets[numCascades-1]+index);
		}

		/**
		 * Implement this for joy. Some things must ye know
		 * input registers:
		 * fs3 - shadow map texture
		 * ft0 - center sample coordinates
		 * fc3.xy - (.5, -.5)
		 * fc[offset] (getDirectionalSampleCode(0)) contains depth map decode data
		 * fc[offset+1].x (getDirectionalSampleCode(1)+".x") contains epsilon offset
		 * ft6 - view position (does not need to be kept)
		 * ft5.xy --> scale of the current projection (used to keep neighbourhood samples in the same radius across splits), only if needsProjectionScale is set to true
		 *
		 * output register
		 * ft0.w: shadow amount (0 if in shadow, 1 if not)
		 */
		arcane function getSampleCode(numCascades : uint) : String
		{
			throw new AbstractMethodError();
			return null;
		}

		arcane function activate(stage3DProxy : Stage3DProxy, light : DirectionalLight, numCascades : uint) : void
		{
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, _constantRegisterOffsets[numCascades-1], _data, _numConstantRegisters);
		}

		arcane function deactivate(stage3DProxy : Stage3DProxy) : void
		{

		}

		arcane function dispose() : void
		{

		}
	}
}
