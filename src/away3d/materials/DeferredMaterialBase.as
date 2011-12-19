package away3d.materials
{
	import away3d.arcane;
	import away3d.errors.AbstractMethodError;
	import away3d.materials.pass.DeferredNormalDepthPass;
	import away3d.materials.pass.DeferredSpecularPass;
	import away3d.materials.passes.MaterialPassBase;
	import away3d.textures.Texture2DBase;

	use namespace arcane;

	// todo: provide different specular and normal passes to accomplish things like fresnel specularity, water normals, etc
	// or just put fresnelPower as a property on specular?
	// todo: allow for animated uvs
	public class DeferredMaterialBase extends MaterialBase
	{
		protected var _albedoPass : MaterialPassBase;
		protected var _normalDepthPass : DeferredNormalDepthPass;
		protected var _specularPass : DeferredSpecularPass;

		public function DeferredMaterialBase()
		{
			// allow the DeferredEntityCollector test to which renderable batch to assign this
			_classification = "deferred";
			_albedoPass = createAlbedoPass();
			_normalDepthPass = new DeferredNormalDepthPass();
			_specularPass = new DeferredSpecularPass();

			addPass(_normalDepthPass);
			addPass(_specularPass);
			addPass(_albedoPass);
		}

		override public function set blendMode(value : String) : void
		{
			throw new Error("Cannot change blend modes for deferred materials!");
			super.blendMode = value;
		}

		protected function createAlbedoPass() : MaterialPassBase
		{
			throw new AbstractMethodError();
			return null;
		}

		public function get gloss() : Number
		{
			return _specularPass.gloss;
		}

		public function set gloss(value : Number) : void
		{
			_specularPass.gloss = value;
		}

		public function get specular() : Number
		{
			return _specularPass.strength;
		}

		public function set specular(value : Number) : void
		{
			_specularPass.strength = value;
		}

		public function get specularColor() : uint
		{
			return _specularPass.specularColor;
		}

		public function set specularColor(value : uint) : void
		{
			_specularPass.specularColor = value;
		}

		public function get normalMap() : Texture2DBase
		{
			return _normalDepthPass.normalMap;
		}

		public function set normalMap(value : Texture2DBase) : void
		{
			_normalDepthPass.normalMap = value;
		}

		public function get specularMap() : Texture2DBase
		{
			return _specularPass.specularMap;
		}

		public function set specularMap(value : Texture2DBase) : void
		{
			_specularPass.specularMap = value;
		}

		arcane function get albedoPass() : MaterialPassBase
		{
			return _albedoPass;
		}

		arcane function get normalDepthPass() : MaterialPassBase
		{
			return _normalDepthPass;
		}

		arcane function get specularPass() : MaterialPassBase
		{
			return _specularPass;
		}
	}
}
