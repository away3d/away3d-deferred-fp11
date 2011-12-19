package away3d.core.data
{
	import away3d.core.managers.Stage3DProxy;
	import away3d.textures.BitmapTexture;
	import away3d.textures.Texture2DBase;

	import flash.display.BitmapData;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;

	public class DitherTextureModel
	{
		private var _grainBitmapDatas : Array = [];
		private var _grainTextures : Array = [];
		private var _grainUsages : Array = [];

		private static var _instance : DitherTextureModel;

		public function DitherTextureModel()
		{
		}

		public static function getInstance() : DitherTextureModel
		{
			return _instance ||= new DitherTextureModel();
		}

		public function getTexture(size : int = 64) : Texture2DBase
		{
			if (!_grainUsages[size]) {
				_grainUsages[size] = 1;
				initGrainTexture(size);
			}
			return _grainTextures[size];
		}

		public function freeTexture(size : int = 64) : void
		{
			if (--_grainUsages[size] == 0) {
				_grainTextures[size].dispose();
				_grainBitmapDatas[size].dispose();
				_grainBitmapDatas[size] = null;
				_grainTextures[size] = null;
			}
		}

		private function initGrainTexture(size : int) : void
		{
			_grainBitmapDatas[size] = new BitmapData(size, size, false);
			var vec : Vector.<uint> = new Vector.<uint>();

			// specifically engineered texture to guarantee nice spherical distribution
			if (size == 4) {
				init4x4(vec);
			}
			else {
				var len : uint = 4096;
				var step : Number = 1/2048;
				var inv : Number = 1-step;
				var r : Number,  g : Number;

				for (var i : uint = 0; i < len; ++i) {
					r = 2*(Math.random() - .5)*inv;
					g = 2*(Math.random() - .5)*inv;
					if (r < 0) r -= step;
					else r += step;
					if (g < 0) g -= step;
					else g += step;

					vec[i] = (((r*.5 + .5)*0xff) << 16) | (((g*.5 + .5)*0xff) << 8);
				}
			}
			_grainBitmapDatas[size].setVector(_grainBitmapDatas[size].rect, vec);
			_grainTextures[size] = new BitmapTexture(_grainBitmapDatas[size]);
		}

		private function init4x4(vec : Vector.<uint>) : void
		{
			vec[0] = 0x401d4b;
			vec[1] = 0xca442b;
			vec[2] = 0x17aa44;
			vec[3] = 0xa1d124;
			vec[4] = 0x5d2dda;
			vec[5] = 0xe754ba;
			vec[6] = 0x34bad3;
			vec[7] = 0xbee1b3;
			vec[8] = 0x526c09;
			vec[9] = 0xc32346;
			vec[10] = 0x88eb3c;
			vec[11] = 0xf9a278;
			vec[12] = 0x55c86;
			vec[13] = 0x7613c2;
			vec[14] = 0x3bdbb8;
			vec[15] = 0xac92f5;
		}
	}
}
