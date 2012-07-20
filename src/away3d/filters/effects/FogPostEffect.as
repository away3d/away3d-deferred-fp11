package away3d.filters.effects
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.Stage3DProxy;

	import flash.display3D.Context3DProgramType;

	use namespace arcane;

	public class FogPostEffect extends PostEffectBase
	{
		private var _fogColor : uint;
		private var _data : Vector.<Number>;
		private var _constantOffset : int;
		private var _minDistance : Number;
		private var _maxDistance : Number;

		public function FogPostEffect(minDistance : Number, maxDistance : Number, fogColor : uint = 0x808080)
		{
			_data = new <Number>[0, 0, 0, 1, 0, 0, 0, 1];
			_needsDepth = true;
			_minDistance = minDistance;
			_maxDistance = maxDistance;
			this.fogColor = fogColor;
		}

		public function get fogColor() : uint
		{
			return _fogColor;
		}

		public function set fogColor(value : uint) : void
		{
			_fogColor = value;
			_data[0] = ((value >> 16) & 0xff)/0xff;
			_data[1] = ((value >> 8) & 0xff)/0xff;
			_data[2] = (value & 0xff)/0xff;
		}

		override arcane function activate(stage3DProxy : Stage3DProxy, camera : Camera3D) : void
		{
			var near : Number = camera.lens.near;
			var far : Number = camera.lens.far;
			var scale : Number = far - near;
			_data[4] = _minDistance/scale;
			_data[5] = scale/(_maxDistance - _minDistance);
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, _constantOffset, _data, 2);
		}

		override arcane function getFragmentCode(constantOffset : int) : String
		{
			_constantOffset = constantOffset;
			var colorReg : String = "fc" + _constantOffset;
			var dataReg : String = "fc" + (_constantOffset+1);
			return 	"sub ft3.xyz, " + colorReg + ".xyz, ft2.xyz\n" + 			// (fogColor- col)

					// (depth - min)/(max-min)
					"sub ft4.w, ft0.w, "+dataReg+".x\n" +
					"mul ft4.w, ft4.w, "+dataReg+".y\n" +
					"sat ft4.w, ft4.w\n" +

				// prevent skybox from being fogged
					"slt ft3.w, ft0.w, "+colorReg+".w\n" +
					"mul ft3.w, ft3.w, ft4.w\n" +

					"mul ft3.xyz, ft3.xyz, ft3.w\n" +			// (fogColor- col)*fogRatio
					"add ft2.xyz, ft2.xyz, ft3.xyz\n";			// fogRatio*(fogColor- col) + col
		}

		override arcane function get numUsedFragmentConsts() : int
		{
			return 2;
		}
	}
}
