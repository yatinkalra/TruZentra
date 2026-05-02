import { LightningElement, api } from 'lwc';

export default class ZentraFlowSubmitButton extends LightningElement {
    @api buttonLabel = 'Upload & Analyze';

    _footerHidden = false;

    renderedCallback() {
        if (!this._footerHidden) {
            this._footerHidden = true;
            try {
                if (!document.querySelector('style[data-zentra-flow]')) {
                    const style = document.createElement('style');
                    style.setAttribute('data-zentra-flow', 'true');
                    style.textContent = `
                        .slds-flow-footer,
                        .flow-footer,
                        [class*="flowRuntimeForFlexiPage"] footer,
                        flowruntime-flow-footer,
                        flowruntime-navigation-bar { 
                            position: absolute !important;
                            opacity: 0 !important;
                            height: 0 !important;
                            overflow: hidden !important;
                        }
                    `;
                    document.head.appendChild(style);
                }
            } catch (e) { /* ignore */ }
        }
    }

    handleClick() {
        try {
            const selectors = [
                'flowruntime-navigation-bar button',
                'flowruntime-flow-footer button',
                '.slds-flow-footer button',
                '.flow-footer button',
                'footer button'
            ];
            for (let i = 0; i < selectors.length; i++) {
                const btn = document.querySelector(selectors[i]);
                if (btn) {
                    btn.click();
                    return;
                }
            }
            const allBtns = document.querySelectorAll('button');
            for (let j = 0; j < allBtns.length; j++) {
                const text = allBtns[j].textContent || '';
                if (text.trim() === this.buttonLabel || text.trim() === 'Next') {
                    allBtns[j].click();
                    return;
                }
            }
        } catch (ex) { /* ignore */ }
    }

    disconnectedCallback() {
        try {
            const style = document.querySelector('style[data-zentra-flow]');
            if (style) style.remove();
        } catch (e) { /* ignore */ }
    }
}