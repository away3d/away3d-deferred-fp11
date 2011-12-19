package away3d.materials
{
	import away3d.materials.pass.DeferredColorAlbedoPass;
	import away3d.materials.passes.MaterialPassBase;

	public class DeferredColorMaterial extends DeferredMaterialBase
	{
		public function DeferredColorMaterial(color : uint = 0xffffff)
		{
			super();
			this.color = color;
		}

		override protected function createAlbedoPass() : MaterialPassBase
		{
			return new DeferredColorAlbedoPass();
		}

		public function get color() : uint
		{
			return DeferredColorAlbedoPass(_albedoPass).color;
		}

		public function set color(value : uint) : void
		{
			DeferredColorAlbedoPass(_albedoPass).color = value;
		}
	}
}
