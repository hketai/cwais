<script setup>
import { computed, onMounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const integrations = ref([]);
const isFetching = ref(false);
const shopifyHook = ref(null);

// Connection test status for each integration
const connectionTestStatus = ref({});
const isTestingConnection = ref({});

// All available integrations
const allIntegrations = computed(() => {
  return [
    {
      id: 'shopify',
      name: 'Shopify',
      description:
        'Shopify mağazanıza bağlanın ve sipariş bilgilerini sorgulayın',
      icon: 'i-logos-shopify',
      connected: shopifyHook.value && shopifyHook.value.id,
      hook: shopifyHook.value,
      comingSoon: false,
    },
    {
      id: 'ikas',
      name: 'İkas',
      description: 'İkas mağazanıza bağlanın ve sipariş bilgilerini sorgulayın',
      icon: 'i-lucide-store',
      connected: false,
      hook: null,
      comingSoon: true,
    },
  ];
});

// Shopify connection dialog
const shopifyDialogRef = ref(null);
const shopifyStoreUrl = ref('');
const shopifyAccessKey = ref('');
const isConnectingShopify = ref(false);
const shopifyError = ref('');

// Test order query
const testOrderDialogRef = ref(null);
const testContactId = ref('');
const testOrders = ref([]);
const isFetchingOrders = ref(false);

const isEmpty = computed(() => {
  return allIntegrations.value.length === 0;
});

const fetchIntegrations = async () => {
  isFetching.value = true;
  try {
    const response = await shopifyAPI.getHook();

    // Handle both direct response and nested data
    const hookData = response.data?.hook || response.hook;

    if (hookData && (hookData.id || hookData.reference_id)) {
      shopifyHook.value = {
        id: hookData.id,
        reference_id: hookData.reference_id,
        enabled: hookData.enabled !== false,
      };
      integrations.value = [
        {
          id: 'shopify',
          enabled: shopifyHook.value.enabled,
          reference_id: shopifyHook.value.reference_id,
        },
      ];
    } else {
      shopifyHook.value = null;
      integrations.value = [];
    }
  } catch (error) {
    if (error.response?.status === 404) {
      // Hook bulunamadı, entegrasyon yok
      shopifyHook.value = null;
      integrations.value = [];
    } else {
      shopifyHook.value = null;
      integrations.value = [];
    }
  } finally {
    isFetching.value = false;
  }
};

const openShopifyDialog = () => {
  shopifyStoreUrl.value = shopifyHook.value?.reference_id || '';
  shopifyAccessKey.value = '';
  shopifyError.value = '';
  if (shopifyDialogRef.value) {
    shopifyDialogRef.value.open();
  }
};

const handleShopifyDisconnect = async () => {
  try {
    await shopifyAPI.disconnect();
    await fetchIntegrations();
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_SUCCESS'), 'success');
  } catch (error) {
    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.DISCONNECT_ERROR'), 'error');
  }
};

const handleIntegrationClick = integration => {
  // Coming soon entegrasyonlar için tıklamayı devre dışı bırak
  if (integration.comingSoon) {
    return;
  }

  if (integration.connected) {
    // Bağlı entegrasyon için ayarlar dialogunu aç
    if (integration.id === 'shopify') {
      openShopifyDialog();
    }
  } else if (integration.id === 'shopify') {
    // Bağlı olmayan entegrasyon için bağlantı dialogunu aç
    openShopifyDialog();
  }
};

const toggleIntegration = async integration => {
  if (integration.connected) {
    // Bağlantıyı kes
    if (integration.id === 'shopify') {
      await handleShopifyDisconnect();
    }
  } else if (integration.id === 'shopify') {
    // Bağlan
    openShopifyDialog();
  }
};

const testConnection = async integration => {
  if (!integration.connected) return;

  isTestingConnection.value[integration.id] = true;
  connectionTestStatus.value[integration.id] = null;

  try {
    if (integration.id === 'shopify') {
      await shopifyAPI.testConnection();
      connectionTestStatus.value[integration.id] = 'success';
      useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.TEST_SUCCESS'), 'success');
    }
  } catch (error) {
    connectionTestStatus.value[integration.id] = 'error';
    useAlert(
      `${t('SIDEBAR.INTEGRATIONS.SHOPIFY.TEST_ERROR')}: ${error.response?.data?.error || error.message}`,
      'error'
    );
  } finally {
    isTestingConnection.value[integration.id] = false;
    // 3 saniye sonra durumu temizle
    setTimeout(() => {
      connectionTestStatus.value[integration.id] = null;
    }, 3000);
  }
};

const validateStoreUrl = url => {
  const pattern = /^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$/;
  return pattern.test(url);
};

const handleShopifyConnect = async () => {
  try {
    shopifyError.value = '';
    if (!validateStoreUrl(shopifyStoreUrl.value)) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_MESSAGE');
      return;
    }
    if (!shopifyAccessKey.value || shopifyAccessKey.value.trim().length === 0) {
      shopifyError.value = t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_MESSAGE');
      return;
    }

    isConnectingShopify.value = true;
    const { data } = await shopifyAPI.connectWithAccessKey({
      shopDomain: shopifyStoreUrl.value,
      accessKey: shopifyAccessKey.value,
    });

    // Update hook data from response
    const hookData = data?.hook || data;

    if (hookData && (hookData.id || hookData.reference_id)) {
      shopifyHook.value = {
        id: hookData.id,
        reference_id: hookData.reference_id,
        enabled: hookData.enabled !== false,
      };
      integrations.value = [
        {
          id: 'shopify',
          enabled: shopifyHook.value.enabled,
          reference_id: shopifyHook.value.reference_id,
        },
      ];
    } else {
      // Fallback to fetch if response format is different
      await fetchIntegrations();
    }

    useAlert(t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECT_SUCCESS'), 'success');
    if (shopifyDialogRef.value) {
      shopifyDialogRef.value.close();
    }
  } catch (error) {
    shopifyError.value =
      error.response?.data?.error ||
      error.message ||
      t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECTION_ERROR');
  } finally {
    isConnectingShopify.value = false;
  }
};

const handleTestOrderQuery = async () => {
  if (!testContactId.value) {
    useAlert(t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_REQUIRED'), 'error');
    return;
  }

  isFetchingOrders.value = true;
  try {
    const { data } = await shopifyAPI.getOrders(testContactId.value);
    testOrders.value = data.orders || [];
    if (testOrders.value.length === 0) {
      useAlert(t('SIDEBAR.INTEGRATIONS.TEST_ORDER.NO_ORDERS'), 'info');
    }
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        t('SIDEBAR.INTEGRATIONS.TEST_ORDER.QUERY_ERROR'),
      'error'
    );
    testOrders.value = [];
  } finally {
    isFetchingOrders.value = false;
  }
};

onMounted(() => {
  fetchIntegrations();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="$t('SIDEBAR.SATURN_INTEGRATIONS')"
    :action-button-text="null"
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="isEmpty"
    :total-records="allIntegrations.length"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
  >
    <template #emptyStateSection>
      <div class="text-center py-12">
        <p class="text-lg text-n-slate-11">
          {{ $t('SIDEBAR.INTEGRATIONS.EMPTY_STATE_TITLE') }}
        </p>
        <p class="text-sm text-n-slate-10 mt-2">
          {{ $t('SIDEBAR.INTEGRATIONS.EMPTY_STATE_DESCRIPTION') }}
        </p>
      </div>
    </template>

    <template #contentArea>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div
          v-for="integration in allIntegrations"
          :key="integration.id"
          class="bg-n-slate-1 border border-n-slate-4 rounded-lg p-6 transition-colors relative"
          :class="{
            'cursor-pointer hover:border-n-slate-6': !integration.comingSoon,
            'opacity-50 cursor-not-allowed': integration.comingSoon,
          }"
          @click="handleIntegrationClick(integration)"
        >
          <div
            v-if="integration.comingSoon"
            class="absolute top-3 right-3 bg-n-amber-9/20 text-n-amber-11 text-xs font-medium px-2 py-1 rounded"
          >
            {{ $t('SIDEBAR.INTEGRATIONS.COMING_SOON') }}
          </div>
          <div class="flex items-start justify-between mb-4">
            <div class="flex items-center gap-3 flex-1">
              <div
                class="w-12 h-12 bg-n-slate-2 rounded-lg flex items-center justify-center flex-shrink-0"
              >
                <Icon :icon="integration.icon" class="w-8 h-8" />
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="text-base font-semibold text-n-slate-12 truncate">
                  {{ integration.name }}
                </h3>
                <p class="text-sm text-n-slate-11 mt-1 line-clamp-2">
                  {{ integration.description }}
                </p>
              </div>
            </div>
            <div
              v-if="integration.connected && !integration.comingSoon"
              class="flex-shrink-0 ml-2 flex items-center gap-2"
            >
              <button
                type="button"
                class="flex items-center justify-center w-8 h-8 rounded-lg transition-colors"
                :class="{
                  'bg-n-teal-9/20 text-n-teal-11':
                    connectionTestStatus[integration.id] === 'success',
                  'bg-n-ruby-9/20 text-n-ruby-11':
                    connectionTestStatus[integration.id] === 'error',
                  'bg-n-slate-2 text-n-slate-11 hover:bg-n-slate-3':
                    !connectionTestStatus[integration.id],
                }"
                :disabled="isTestingConnection[integration.id]"
                @click.stop="testConnection(integration)"
              >
                <Icon
                  v-if="isTestingConnection[integration.id]"
                  icon="i-lucide-loader-2"
                  class="w-4 h-4 animate-spin"
                />
                <Icon
                  v-else-if="connectionTestStatus[integration.id] === 'success'"
                  icon="i-lucide-check"
                  class="w-4 h-4"
                />
                <Icon
                  v-else-if="connectionTestStatus[integration.id] === 'error'"
                  icon="i-lucide-x"
                  class="w-4 h-4"
                />
                <Icon v-else icon="i-lucide-link" class="w-4 h-4" />
              </button>
              <div @click.stop>
                <Switch
                  :model-value="integration.connected"
                  @change="() => toggleIntegration(integration)"
                />
              </div>
            </div>
            <div v-else-if="!integration.comingSoon" class="flex-shrink-0 ml-2">
              <Icon
                icon="i-lucide-chevron-right"
                class="w-5 h-5 text-n-slate-9"
              />
            </div>
          </div>
          <div
            v-if="integration.connected && integration.hook?.reference_id"
            class="pt-4 border-t border-n-slate-4"
          >
            <p class="text-xs text-n-slate-11">
              <span class="font-medium">{{
                $t('SIDEBAR.INTEGRATIONS.STORE')
              }}</span>
              {{ integration.hook.reference_id }}
            </p>
          </div>
        </div>
      </div>
    </template>

    <!-- Shopify Connect Dialog -->
    <Dialog
      ref="shopifyDialogRef"
      :title="
        shopifyHook
          ? $t('SIDEBAR.INTEGRATIONS.SHOPIFY.EDIT_TITLE')
          : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.CONNECT_TITLE')
      "
      :is-loading="isConnectingShopify"
      @confirm="handleShopifyConnect"
      @close="
        () => {
          shopifyStoreUrl = '';
          shopifyAccessKey = '';
          shopifyError = '';
        }
      "
    >
      <div class="space-y-4">
        <Input
          v-model="shopifyStoreUrl"
          :label="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_LABEL')"
          :placeholder="
            $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_PLACEHOLDER')
          "
          :message="
            shopifyError && shopifyError.includes('URL')
              ? shopifyError
              : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.STORE_URL_MESSAGE')
          "
          :message-type="
            shopifyError && shopifyError.includes('URL') ? 'error' : 'info'
          "
        />
        <Input
          v-model="shopifyAccessKey"
          :label="$t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_LABEL')"
          type="password"
          :placeholder="
            $t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_PLACEHOLDER')
          "
          :message="
            shopifyError && shopifyError.includes('Access')
              ? shopifyError
              : $t('SIDEBAR.INTEGRATIONS.SHOPIFY.ACCESS_KEY_MESSAGE')
          "
          :message-type="
            shopifyError && shopifyError.includes('Access') ? 'error' : 'info'
          "
        />
      </div>
    </Dialog>

    <!-- Test Order Query Dialog -->
    <Dialog
      ref="testOrderDialogRef"
      :title="$t('SIDEBAR.INTEGRATIONS.TEST_ORDER.TITLE')"
      :is-loading="isFetchingOrders"
      @confirm="handleTestOrderQuery"
      @close="
        () => {
          testContactId = '';
          testOrders = [];
        }
      "
    >
      <Input
        v-model="testContactId"
        :label="$t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_LABEL')"
        :placeholder="
          $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_PLACEHOLDER')
        "
        :message="$t('SIDEBAR.INTEGRATIONS.TEST_ORDER.CONTACT_ID_MESSAGE')"
        message-type="info"
      />
      <div v-if="testOrders.length > 0" class="mt-4">
        <h4 class="font-semibold mb-2 text-n-slate-12">
          {{
            $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.ORDERS_TITLE_WITH_COUNT', {
              count: testOrders.length,
            })
          }}
        </h4>
        <div class="space-y-2 max-h-64 overflow-y-auto">
          <div
            v-for="order in testOrders"
            :key="order.id"
            class="p-3 bg-n-slate-2 border border-n-slate-4 rounded"
          >
            <div class="flex justify-between items-start">
              <div>
                <p class="font-medium text-n-slate-12">
                  {{ $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.ORDER_NUMBER')
                  }}{{ order.id }}
                </p>
                <p class="text-sm text-n-slate-11">
                  {{ new Date(order.created_at).toLocaleDateString('tr-TR') }}
                </p>
                <p class="text-sm text-n-slate-11">
                  <span class="font-medium">{{
                    $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.STATUS')
                  }}</span>
                  {{
                    order.fulfillment_status ||
                    $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.PENDING')
                  }}
                </p>
              </div>
              <div class="text-right">
                <p class="font-semibold text-n-slate-12">
                  {{ order.total_price }} {{ order.currency }}
                </p>
                <a
                  :href="order.admin_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-xs text-n-blue-11 hover:text-n-blue-12 hover:underline"
                >
                  {{ $t('SIDEBAR.INTEGRATIONS.TEST_ORDER.VIEW_IN_SHOPIFY') }}
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Dialog>
  </SaturnPageLayout>
</template>
