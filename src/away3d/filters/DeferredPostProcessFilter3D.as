package away3d.filters
{
	import away3d.core.render.DeferredRenderer;
	import away3d.filters.effects.PostEffectBase;
	import away3d.filters.tasks.Filter3DDeferredPostProcessTask;

	public class DeferredPostProcessFilter3D extends Filter3DBase
	{
		private var _task : Filter3DDeferredPostProcessTask;

		public function DeferredPostProcessFilter3D(renderer : DeferredRenderer)
		{
			super();
			_task = new Filter3DDeferredPostProcessTask(renderer);
			addTask(_task);
		}

		public function addEffect(effect : PostEffectBase) : void
		{
			_task.addEffect(effect);
		}

		public function removeEffect(effect : PostEffectBase) : void
		{
			_task.removeEffect(effect);
		}

		public function hasEffect(effect : PostEffectBase) : Boolean
		{
			return _task.hasEffect(effect);
		}

		public function getEffectIndex(effect : PostEffectBase) : int
		{
			return _task.getEffectIndex(effect);
		}
	}
}
