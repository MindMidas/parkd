// Cloudflare Turnstile bridge used only for web sign-up. Supabase validates
// every one-time token server-side with the configured Turnstile secret.
window.parkdTurnstileToken = function (siteKey) {
  return new Promise(function (resolve, reject) {
    const deadline = Date.now() + 15000;
    let container;
    let widgetId;
    let settled = false;
    const challengeTimeout = window.setTimeout(function () {
      finishReject(new Error('Bot verification timed out.'));
    }, 90000);

    function cleanup() {
      window.clearTimeout(challengeTimeout);
      try {
        if (window.turnstile && widgetId !== undefined) {
          window.turnstile.remove(widgetId);
        }
      } catch (_) {}
      if (container && container.parentNode) container.parentNode.removeChild(container);
    }

    function finishResolve(token) {
      if (settled) return;
      settled = true;
      cleanup();
      resolve(token);
    }

    function finishReject(error) {
      if (settled) return;
      settled = true;
      cleanup();
      reject(error);
    }

    function start() {
      if (settled) return;
      if (!window.turnstile) {
        if (Date.now() >= deadline) {
          finishReject(new Error('Turnstile did not load.'));
          return;
        }
        window.setTimeout(start, 100);
        return;
      }

      container = document.createElement('div');
      container.setAttribute('aria-label', 'Bot protection challenge');
      container.style.position = 'fixed';
      container.style.left = '50%';
      container.style.bottom = '24px';
      container.style.transform = 'translateX(-50%)';
      container.style.zIndex = '2147483647';
      document.body.appendChild(container);

      try {
        widgetId = window.turnstile.render(container, {
          sitekey: siteKey,
          action: 'signup',
          execution: 'execute',
          appearance: 'interaction-only',
          callback: finishResolve,
          'error-callback': function () {
            finishReject(new Error('Bot verification failed.'));
          },
          'expired-callback': function () {
            finishReject(new Error('Bot verification expired.'));
          }
        });
        window.turnstile.execute(widgetId);
      } catch (_) {
        finishReject(new Error('Bot verification could not start.'));
      }
    }

    start();
  });
};
