<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');

const isDarkMode = ref(document.body.classList.contains('dark'));

const updateDarkMode = () => {
  isDarkMode.value = document.body.classList.contains('dark');
};

let observer = null;
let mediaQuery = null;
let handleMediaChange = null;

onMounted(() => {
  // MutationObserver ile dark class değişikliklerini izle
  observer = new MutationObserver(updateDarkMode);
  observer.observe(document.body, {
    attributes: true,
    attributeFilter: ['class'],
  });

  // Media query ile sistem teması değişikliklerini izle
  mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
  handleMediaChange = () => {
    // Kısa bir gecikme ile body class'ının güncellenmesini bekle
    setTimeout(updateDarkMode, 100);
  };
  mediaQuery.addEventListener('change', handleMediaChange);
});

onUnmounted(() => {
  if (observer) {
    observer.disconnect();
  }
  if (mediaQuery && handleMediaChange) {
    mediaQuery.removeEventListener('change', handleMediaChange);
  }
});

const logoSrc = computed(() => {
  if (isDarkMode.value && globalConfig.value.logoDark) {
    return globalConfig.value.logoDark;
  }
  return globalConfig.value.logo || globalConfig.value.logoThumbnail;
});
</script>

<template>
  <img v-if="logoSrc" v-bind="attrs" :src="logoSrc" />
  <svg
    v-else
    v-once
    v-bind="attrs"
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <g clip-path="url(#saturn-logo-clip-2342424e23u32098)">
      <path
        d="M8 16C12.4183 16 16 12.4183 16 8C16 3.58172 12.4183 0 8 0C3.58172 0 0 3.58172 0 8C0 12.4183 3.58172 16 8 16Z"
        fill="#6366F1"
      />
      <path d="M10.5 5.5L8 3L5.5 5.5L8 8L10.5 5.5Z" fill="white" />
      <path d="M8 8L10.5 10.5L8 13L5.5 10.5L8 8Z" fill="white" />
    </g>
    <defs>
      <clipPath id="saturn-logo-clip-2342424e23u32098">
        <rect width="16" height="16" fill="white" />
      </clipPath>
    </defs>
  </svg>
</template>
