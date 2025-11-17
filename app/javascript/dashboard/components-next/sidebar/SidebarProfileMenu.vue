<script setup>
import { computed, ref, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import Auth from 'dashboard/api/auth';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import SidebarProfileMenuStatus from './SidebarProfileMenuStatus.vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import subscriptionsAPI from 'dashboard/api/subscriptions';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSeparator,
  DropdownItem,
} from 'next/dropdown-menu/base';
import CustomBrandPolicyWrapper from '../../components/CustomBrandPolicyWrapper.vue';

const emit = defineEmits(['close', 'openKeyShortcutModal']);

defineOptions({
  inheritAttrs: false,
});

const { t } = useI18n();
const router = useRouter();

const currentUser = useMapGetter('getCurrentUser');
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const accountId = useMapGetter('getCurrentAccountId');
const globalConfig = useMapGetter('globalConfig/get');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const currentSubscription = ref(null);
const loading = ref(false);

const fetchCurrentSubscription = async () => {
  try {
    loading.value = true;
    const response = await subscriptionsAPI.current();
    currentSubscription.value = response.data;
  } catch (err) {
    // Silently fail if no subscription
    currentSubscription.value = null;
  } finally {
    loading.value = false;
  }
};

const goToSubscriptionPage = () => {
  router.push({
    name: 'subscriptions_index',
    params: { accountId: accountId.value },
  });
  emit('close');
};

onMounted(() => {
  fetchCurrentSubscription();
});

// Account değiştiğinde subscription'ı yeniden yükle
watch(accountId, () => {
  fetchCurrentSubscription();
});

const showChatSupport = computed(() => {
  return (
    isFeatureEnabledonAccount.value(
      accountId.value,
      FEATURE_FLAGS.CONTACT_CHATWOOT_SUPPORT_TEAM
    ) && globalConfig.value.chatwootInboxToken
  );
});

const menuItems = computed(() => {
  return [
    {
      show: showChatSupport.value,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.CONTACT_SUPPORT'),
      icon: 'i-lucide-life-buoy',
      click: () => {
        window.$chatwoot.toggle();
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.KEYBOARD_SHORTCUTS'),
      icon: 'i-lucide-keyboard',
      click: () => {
        emit('openKeyShortcutModal');
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.PROFILE_SETTINGS'),
      icon: 'i-lucide-user-pen',
      link: { name: 'profile_settings_index' },
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.APPEARANCE'),
      icon: 'i-lucide-palette',
      click: () => {
        const ninja = document.querySelector('ninja-keys');
        ninja.open({ parent: 'appearance_settings' });
      },
    },
    {
      show: true,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.DOCS'),
      icon: 'i-lucide-book',
      link: 'https://www.chatwoot.com/hc/user-guide/en',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: true,
      showOnCustomBrandedInstance: false,
      label: t('SIDEBAR_ITEMS.CHANGELOG'),
      icon: 'i-lucide-scroll-text',
      link: 'https://www.chatwoot.com/changelog/',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: currentUser.value.type === 'SuperAdmin',
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.SUPER_ADMIN_CONSOLE'),
      icon: 'i-lucide-castle',
      link: '/super_admin',
      nativeLink: true,
      target: '_blank',
    },
    {
      show: true,
      showOnCustomBrandedInstance: true,
      label: t('SIDEBAR_ITEMS.LOGOUT'),
      icon: 'i-lucide-power',
      click: Auth.logout,
    },
  ];
});

const allowedMenuItems = computed(() => {
  return menuItems.value.filter(item => item.show);
});
</script>

<template>
  <DropdownContainer class="relative w-full min-w-0" @close="emit('close')">
    <template #trigger="{ toggle, isOpen }">
      <button
        class="flex flex-col gap-1 p-1 w-full text-left rounded-lg cursor-pointer hover:bg-n-alpha-1"
        :class="{ 'bg-n-alpha-1': isOpen }"
        @click="toggle"
      >
        <!-- Paket Bilgisi - Avatar'ın Üstünde -->
        <button
          v-if="currentSubscription?.plan"
          type="button"
          class="text-xs font-semibold leading-4 truncate text-n-iris-11 hover:text-n-iris-12 cursor-pointer transition-colors w-full text-left px-1"
          @click.stop="goToSubscriptionPage"
        >
          {{ currentSubscription.plan.name }}
        </button>
        <!-- Avatar ve Kullanıcı Bilgileri -->
        <div class="flex gap-2 items-center">
          <Avatar
            :size="32"
            :name="currentUser.available_name"
            :src="currentUser.avatar_url"
            :status="currentUserAvailability"
            class="flex-shrink-0"
            rounded-full
          />
          <div class="min-w-0 flex-1">
            <!-- Kullanıcı Adı -->
            <div class="text-sm font-medium leading-4 truncate text-n-slate-12">
              {{ currentUser.available_name }}
            </div>
            <!-- Email -->
            <div class="text-xs truncate text-n-slate-11">
              {{ currentUser.email }}
            </div>
          </div>
        </div>
      </button>
    </template>
    <DropdownBody class="bottom-12 z-50 mb-2 w-80 ltr:left-0 rtl:right-0">
      <SidebarProfileMenuStatus />
      <DropdownSeparator />
      <template v-for="item in allowedMenuItems" :key="item.label">
        <CustomBrandPolicyWrapper
          :show-on-custom-branded-instance="item.showOnCustomBrandedInstance"
        >
          <DropdownItem v-if="item.show" v-bind="item" />
        </CustomBrandPolicyWrapper>
      </template>
    </DropdownBody>
  </DropdownContainer>
</template>
