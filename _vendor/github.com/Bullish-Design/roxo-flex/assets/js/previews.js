document.querySelectorAll(".link-preview").forEach((preview, index) => {
  const toggle = preview.querySelector(".link-preview__toggle");
  const card = preview.querySelector(".link-preview__card");
  const destination = preview.querySelector(".link-preview__destination");
  const close = preview.querySelector(".link-preview__close");
  let pinned = false;
  let hideTimer;

  card.id = `link-preview-${index + 1}`;
  toggle.setAttribute("aria-controls", card.id);
  toggle.hidden = false;

  function place() {
    if (window.innerWidth <= 540) return;
    const trigger = preview.getBoundingClientRect();
    const bounds = card.getBoundingClientRect();
    const left = Math.max(16, Math.min(trigger.left, window.innerWidth - bounds.width - 16));
    let top = trigger.bottom + 8;
    if (top + bounds.height > window.innerHeight - 16) top = trigger.top - bounds.height - 8;
    top = Math.max(16, Math.min(top, window.innerHeight - bounds.height - 16));
    card.style.left = `${left}px`;
    card.style.top = `${top}px`;
  }

  function show() {
    clearTimeout(hideTimer);
    card.hidden = false;
    toggle.setAttribute("aria-expanded", "true");
    place();
  }

  function hide() {
    clearTimeout(hideTimer);
    card.hidden = true;
    toggle.setAttribute("aria-expanded", "false");
  }

  function scheduleHide() {
    if (!pinned) hideTimer = setTimeout(hide, 150);
  }

  preview.addEventListener("pointerenter", event => {
    if (event.pointerType === "mouse") show();
  });
  preview.addEventListener("pointerleave", scheduleHide);
  card.addEventListener("pointerenter", () => clearTimeout(hideTimer));
  toggle.addEventListener("click", () => {
    if (pinned) {
      pinned = false;
      hide();
    } else {
      pinned = true;
      show();
      destination.focus({preventScroll: true});
    }
  });
  close.addEventListener("click", () => {
    pinned = false;
    hide();
    toggle.focus({preventScroll: true});
  });
  document.addEventListener("pointerdown", event => {
    if (!preview.contains(event.target)) {
      pinned = false;
      hide();
    }
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape" && !card.hidden) {
      pinned = false;
      hide();
      toggle.focus({preventScroll: true});
    }
  });
});
