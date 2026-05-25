import UIAbility from "@ohos:app.ability.UIAbility";
import type window from "@ohos:window";
export default class EntryAbility extends UIAbility {
    onWindowStageCreate(windowStage: window.WindowStage): void {
        try {
            windowStage.loadContent('pages/Index');
        }
        catch (error) {
            console.error(`Failed to load content: ${(error as Error).message}`);
        }
    }
}
