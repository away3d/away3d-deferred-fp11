package away3d.materials.pass
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.Stage3DProxy;
	import away3d.materials.passes.MaterialPassBase;

	import flash.display3D.Context3DProgramType;

	use namespace arcane;

	public class DeferredColorAlbedoPass extends MaterialPassBase
	{
		private var _color : uint = 0xffffff;
		private var _data : Vector.<Number>;

		public function DeferredColorAlbedoPass()
		{
			_data = new Vector.<Number>(4, true);
			_data[3] = 1;

			// only vertex data
			_numUsedStreams = 1;
			_numUsedTextures = 0;
		}

		public function get color() : uint
		{
			return _color;
		}

		public function set color(value : uint) : void
		{
			_color = value;
			_data[0] = ((value >> 16) & 0xff)/0xff;
			_data[1] = ((value >> 8) & 0xff)/0xff;
			_data[2] = (value & 0xff)/0xff;
		}

		arcane override function getVertexCode() : String
		{
            var code : String = animation.getAGALVertexCode(this, ["va0"], ["vt0"]);
            // project
            code += "m44 vt1, vt0, vc0		\n" +
                    "mul op, vt1, vc4\n";
			return code;
		}

		arcane override function getFragmentCode() : String
		{
			return "mov oc, fc0";
		}

		arcane override function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, textureRatioX : Number, textureRatioY : Number) : void
		{
			super.activate(stage3DProxy, camera, textureRatioX, textureRatioY);
			stage3DProxy._context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, _data, 1);
		}


	}
}
