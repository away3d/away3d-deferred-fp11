package away3d.materials
{
	import away3d.materials.pass.DeferredTextureAlbedoPass;
	import away3d.materials.passes.MaterialPassBase;
	import away3d.textures.Texture2DBase;

	public class DeferredTextureMaterial extends DeferredMaterialBase
	{
		private var _alphaThreshold : Number;

		public function DeferredTextureMaterial(texture : Texture2DBase, smooth : Boolean = true, repeat : Boolean = false, mipmap : Boolean = true)
		{
			super();
			this.texture = texture;
			this.smooth = smooth;
			this.repeat = repeat;
			this.mipmap = mipmap;
		}

		public function get alphaThreshold() : Number
		{
			return _alphaThreshold;
		}

		public function set alphaThreshold(value : Number) : void
		{
			_alphaThreshold = value;

			DeferredTextureAlbedoPass(_albedoPass).alphaThreshold = value;
			_normalDepthPass.alphaThreshold = value;
			_specularPass.alphaThreshold = value;
			_depthPass.alphaThreshold = value;
			_distancePass.alphaThreshold = value;
		}

		override protected function createAlbedoPass() : MaterialPassBase
		{
			return new DeferredTextureAlbedoPass();
		}

		/**
		 * The albedo texture for the material
		 */
		public function get texture() : Texture2DBase
		{
			return DeferredTextureAlbedoPass(_albedoPass).texture;
		}

		/**
		 * The albedo texture for the material
		 */
		public function set texture(value : Texture2DBase) : void
		{
			DeferredTextureAlbedoPass(_albedoPass).texture = value;
			_normalDepthPass.alphaMask = value;
			_specularPass.alphaMask = value;
			_depthPass.alphaMask = value;
			_distancePass.alphaMask = value;
		}
	}
}
