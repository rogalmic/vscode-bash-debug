export class EventSource {
    private callbacks: { callback: () => void; oneTime: boolean; callCount: number }[] = [];

    public setEvent(): void {
        this.callbacks = this.callbacks.filter(c => !(c.oneTime === true && c.callCount !== 0));
        this.callbacks.forEach(c => {
            c.callback();
            c.callCount++;
        });
    }

    public onEvent(): Promise<void> {
        return new Promise<void>((resolve) => {
            this.scheduleOnce(() => resolve());
        });
    }

    public schedule(callback: () => void): void {
        const multipleTimesCallback =
        {
            callback: () => { callback(); }, oneTime: false, callCount: 0
        };

        this.callbacks.push(multipleTimesCallback);
    }

    public scheduleOnce(callback: () => void): void {
        const oneTimeCallback =
        {
            callback: () => { callback(); }, oneTime: true, callCount: 0
        };

        this.callbacks.push(oneTimeCallback);
    }
}