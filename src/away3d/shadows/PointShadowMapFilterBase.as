package away3d.shadows
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.errors.AbstractMethodError;
	import away3d.lights.DirectionalLight;
	import away3d.lights.PointLight;

	import flash.display3D.Context3DProgramType;

	use namespace arcane;

	public class PointShadowMapFilterBase
	{
		protected var _data : Vector.<Number>;
		private var _numConstantRegisters : uint;
		private var _constantRegisterOffset : uint;

		public function PointShadowMapFilterBase(numConstantRegisters : uint = 2)
		{
			_numConstantRegisters = numConstantRegisters;
			_data = new Vector.<Number>(numConstantRegisters*4, true);
			_data[0] = 1.0;
			_data[1] = 1.0/255.0;
			_data[2] = 1.0/65025.0;
			_data[3] = 1.0/16581375.0;
			_data[4] = -.002;
		}

		public function get depthOffset() : Number
		{
			return -_data[4];
		}

		public function set depthOffset(value : Number) : void
		{
			_data[4] = -value;
		}

		public function get constantRegisterOffset() : uint
		{
			return _constantRegisterOffset;
		}

		public function set constantRegisterOffset(value : uint) : void
		{
			_constantRegisterOffset = value;
		}

		protected function getConstantRegister(index : uint) : String
		{
			if (index > _numConstantRegisters) throw new Error("Overflow! You need to increase the numConstantRegisters passed in the ShadowMapFilterBase constructor");

			return "fc"+(_constantRegisterOffset+index);
		}

		/**
		 * Implement this for joy. Some things must ye know
		 * input registers:
		 * fs3 - shadow map texture
		 * ft0.xyz - (3d) sample coordinates
		 * ft0.w - normalized distance to fragment -> compare against this
		 * fc[offset] (getDirectionalSampleCode(0)) contains depth map decode data
		 * fc[offset+1].x (getDirectionalSampleCode(1)+".x") contains epsilon offset
		 * ft6 - view position
		 * ft5.xy --> scale of the current projection (used to keep neighbourhood samples in the same radius across splits), only if needsProjectionScale is set to true
		 *
		 * output register
		 * ft0.w - shadow value between [0 - 1]
		 */
		arcane function getSampleCode() : String
		{
			throw new AbstractMethodError();
			return null;
		}

		arcane function activate(stage3DProxy : Stage3DProxy, light : PointLight) : void
		{
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, _constantRegisterOffset, _data, _numConstantRegisters);
		}

		arcane function deactivate(stage3DProxy : Stage3DProxy) : void
		{

		}

		arcane function dispose() : void
		{

		}
	}
}
