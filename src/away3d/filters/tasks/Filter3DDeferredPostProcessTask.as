package away3d.filters.tasks
{
	import away3d.arcane;
	import away3d.cameras.Camera3D;
	import away3d.core.managers.RTTBufferManager;
	import away3d.core.managers.Stage3DProxy;
	import away3d.core.render.DeferredRenderer;
	import away3d.filters.effects.PostEffectBase;

	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.textures.Texture;

	use namespace arcane;

	public class Filter3DDeferredPostProcessTask extends Filter3DDeferredTaskBase
	{

		private var _effects : Vector.<PostEffectBase>;

		public function Filter3DDeferredPostProcessTask(renderer : DeferredRenderer)
		{
			super(renderer);

			_effects = new Vector.<PostEffectBase>();
		}

		public function addEffect(effect : PostEffectBase) : void
		{
			_effects.push(effect);
			invalidateProgram3D();
		}

		public function removeEffect(effect : PostEffectBase) : void
		{
			var index : int = getEffectIndex(effect);
			if (index >= 0)
				_effects.splice(index, 1);
			invalidateProgram3D();
		}

		public function hasEffect(effect : PostEffectBase) : Boolean
		{
			return getEffectIndex(effect) >= 0;
		}

		public function getEffectIndex(effect : PostEffectBase) : int
		{
			return _effects.indexOf(effect);
		}


		override public function activate(stage3DProxy : Stage3DProxy, camera : Camera3D, depthTexture : Texture) : void
		{
			super.activate(stage3DProxy, camera, depthTexture);

			var len : int = _effects.length;
			for (var i : int = 0; i < len; ++i)
				_effects[i].activate(stage3DProxy, camera);
		}

		override public function deactivate(stage3DProxy : Stage3DProxy) : void
		{
			super.deactivate(stage3DProxy);

			var len : int = _effects.length;
			for (var i : int = 0; i < len; ++i)
				_effects[i].deactivate(stage3DProxy);
		}

		override protected function getVertexCode() : String
		{
			updateDependencies();
			return super.getVertexCode();
		}

		override protected function getFragmentCode() : String
		{
			var code : String = super.getFragmentCode();

			var length : int = _effects.length;
			var constantOffset : int = 2;

			for (var i : int = 0; i < length; ++i) {
				code += _effects[i].getFragmentCode(constantOffset);
				constantOffset += _effects[i].numUsedFragmentConsts;
			}

			code += "mov oc, ft2";

			return code;
		}

		private function updateDependencies() : void
		{
			_needsNormals = false;
			_needsPosition = false;
			_needsDepth = false;

			var length : int = _effects.length;
			for (var i : int = 0; i < length; ++i) {
				var effect : PostEffectBase = _effects[i];
				_needsNormals ||= effect.needsNormals;
				_needsPosition ||= effect.needsPosition;
				_needsDepth ||= effect.needsDepth;
			}
		}
	}
}
