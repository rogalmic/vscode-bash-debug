export class EventSource {
	private callbacks = new Array();

	public setEvent() : void {
		this.callbacks = this.callbacks.filter(c => ! (c.oneTime === true && c.callCount !== 0));
		this.callbacks.forEach(c => {
			c.callback();
			c.callCount++;
		});
	}

	public schedule(callback) : void {
		let multipleTimesCallback =
		{
			callback: ()=> { callback(); }, oneTime: false, callCount: 0
		}

		this.callbacks.push(multipleTimesCallback);
	}

	public scheduleOnce(callback) : void {
		let oneTimeCallback =
		{
			callback: ()=> { callback(); }, oneTime: true, callCount: 0
		}

		this.callbacks.push(oneTimeCallback);
	}
}