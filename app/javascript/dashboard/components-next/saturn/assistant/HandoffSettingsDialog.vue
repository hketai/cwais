<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  assistantId: {
    type: Number,
    required: true,
  },
  assistant: {
    type: Object,
    default: null,
  },
  allAssistants: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'updated']);

const { t } = useI18n();

const dialogRef = ref(null);
const isSubmitting = ref(false);
const isHandoffEnabled = ref(false);
const intents = ref([]);

const handoffTargetTypes = [
  { value: 'human', label: t('SATURN.ASSISTANTS.HANDOFF.TARGET_TYPES.HUMAN') },
  {
    value: 'assistant',
    label: t('SATURN.ASSISTANTS.HANDOFF.TARGET_TYPES.ASSISTANT'),
  },
];

const availableAssistants = computed(() => {
  return props.allAssistants.filter(a => a.id !== props.assistantId);
});

function setDefaults() {
  if (props.assistant?.config?.handoff_config) {
    const config = props.assistant.config.handoff_config;
    isHandoffEnabled.value = config.enabled || false;
    intents.value = config.intents || [];
  } else {
    isHandoffEnabled.value = false;
    intents.value = [];
  }
}

function addIntent() {
  intents.value.push({
    id: Date.now().toString(),
    name: '',
    enabled: true,
    keywords: [],
    handoff_target: {
      type: 'human',
      assistant_id: null,
    },
    handoff_message: '',
  });
}

function removeIntent(index) {
  intents.value.splice(index, 1);
}

function updateIntentKeywords(index, keywordsString) {
  const keywords = keywordsString
    .split(',')
    .map(k => k.trim())
    .filter(k => k.length > 0);
  intents.value[index].keywords = keywords;
}

function updateIntentHandoffTarget(index, targetType) {
  intents.value[index].handoff_target = {
    type: targetType,
    assistant_id: targetType === 'assistant' ? null : null,
  };
}

function updateIntentHandoffAssistant(index, assistantId) {
  intents.value[index].handoff_target.assistant_id = assistantId
    ? Number(assistantId)
    : null;
}

const hasErrors = computed(() => {
  return intents.value.some(intent => {
    if (!intent.name || intent.name.trim().length === 0) return true;
    if (!intent.keywords || intent.keywords.length === 0) return true;
    if (
      intent.handoff_target.type === 'assistant' &&
      !intent.handoff_target.assistant_id
    ) {
      return true;
    }
    return false;
  });
});

async function handleSubmit() {
  if (hasErrors.value) {
    useAlert(t('SATURN.ASSISTANTS.HANDOFF.VALIDATION_ERROR'));
    return;
  }

  try {
    isSubmitting.value = true;
    const handoffConfig = {
      enabled: isHandoffEnabled.value,
      intents: intents.value.map(intent => ({
        id: intent.id,
        name: intent.name.trim(),
        enabled: intent.enabled,
        keywords: intent.keywords,
        handoff_target: {
          type: intent.handoff_target.type,
          assistant_id: intent.handoff_target.assistant_id,
        },
        handoff_message: intent.handoff_message?.trim() || '',
      })),
    };

    await saturnAssistantAPI.updateHandoffSettings({
      assistantId: props.assistantId,
      handoffConfig,
    });

    useAlert(t('SATURN.ASSISTANTS.HANDOFF.SAVE_SUCCESS'));
    dialogRef.value.close();
    emit('updated');
    emit('close');
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.message ||
      t('SATURN.ASSISTANTS.HANDOFF.SAVE_ERROR');
    useAlert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
}

function handleClose() {
  dialogRef.value.close();
  emit('close');
}

function open() {
  setDefaults();
  dialogRef.value.open();
}

defineExpose({ open, close: handleClose });

watch(
  () => props.assistant,
  () => {
    if (props.assistant) {
      setDefaults();
    }
  },
  { deep: true, immediate: true }
);

onMounted(() => {
  setDefaults();
});
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('SATURN.ASSISTANTS.HANDOFF.TITLE')"
    :description="$t('SATURN.ASSISTANTS.HANDOFF.DESCRIPTION')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    width="2xl"
    overflow-y-auto
    @close="handleClose"
  >
    <div class="flex flex-col gap-6">
      <label class="flex items-center gap-2 cursor-pointer">
        <input
          v-model="isHandoffEnabled"
          type="checkbox"
          class="cursor-pointer"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('SATURN.ASSISTANTS.HANDOFF.ENABLE') }}
        </span>
      </label>

      <div v-if="isHandoffEnabled" class="flex flex-col gap-6">
        <div class="flex items-center justify-between">
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ $t('SATURN.ASSISTANTS.HANDOFF.INTENTS') }}
          </h4>
          <Button variant="outline" color="blue" size="sm" @click="addIntent">
            {{ $t('SATURN.ASSISTANTS.HANDOFF.ADD_INTENT') }}
          </Button>
        </div>

        <div
          v-for="(intent, index) in intents"
          :key="intent.id"
          class="flex flex-col gap-4 p-4 border border-n-slate-4 rounded-lg bg-n-slate-1"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <input
                v-model="intent.enabled"
                type="checkbox"
                class="cursor-pointer"
              />
              <span class="text-sm font-medium text-n-slate-11">
                {{ $t('SATURN.ASSISTANTS.HANDOFF.INTENT_ENABLED') }}
              </span>
            </div>
            <Button
              variant="ghost"
              color="ruby"
              size="sm"
              @click="removeIntent(index)"
            >
              {{ $t('SATURN.ASSISTANTS.HANDOFF.REMOVE_INTENT') }}
            </Button>
          </div>

          <Input
            v-model="intent.name"
            :label="$t('SATURN.ASSISTANTS.HANDOFF.INTENT_NAME')"
            :placeholder="
              $t('SATURN.ASSISTANTS.HANDOFF.INTENT_NAME_PLACEHOLDER')
            "
            required
          />

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ $t('SATURN.ASSISTANTS.HANDOFF.KEYWORDS') }}
            </label>
            <Input
              :model-value="intent.keywords?.join(', ') || ''"
              :placeholder="
                $t('SATURN.ASSISTANTS.HANDOFF.KEYWORDS_PLACEHOLDER')
              "
              @update:model-value="updateIntentKeywords(index, $event)"
            />
            <p class="mt-1 text-xs text-n-slate-11">
              {{ $t('SATURN.ASSISTANTS.HANDOFF.KEYWORDS_HELP') }}
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ $t('SATURN.ASSISTANTS.HANDOFF.HANDOFF_TARGET') }}
            </label>
            <select
              v-model="intent.handoff_target.type"
              class="w-full px-3 py-2 text-sm border border-n-slate-6 rounded-lg bg-n-slate-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-blue-9"
              @change="updateIntentHandoffTarget(index, $event.target.value)"
            >
              <option
                v-for="type in handoffTargetTypes"
                :key="type.value"
                :value="type.value"
              >
                {{ type.label }}
              </option>
            </select>
          </div>

          <div v-if="intent.handoff_target.type === 'assistant'">
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              {{ $t('SATURN.ASSISTANTS.HANDOFF.SELECT_ASSISTANT') }}
            </label>
            <select
              :value="intent.handoff_target.assistant_id"
              class="w-full px-3 py-2 text-sm border border-n-slate-6 rounded-lg bg-n-slate-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-blue-9"
              @change="updateIntentHandoffAssistant(index, $event.target.value)"
            >
              <option value="">
                {{
                  $t('SATURN.ASSISTANTS.HANDOFF.SELECT_ASSISTANT_PLACEHOLDER')
                }}
              </option>
              <option
                v-for="targetAssistant in availableAssistants"
                :key="targetAssistant.id"
                :value="targetAssistant.id"
              >
                {{ targetAssistant.name }}
              </option>
            </select>
          </div>

          <TextArea
            v-model="intent.handoff_message"
            :label="$t('SATURN.ASSISTANTS.HANDOFF.HANDOFF_MESSAGE')"
            :placeholder="
              $t('SATURN.ASSISTANTS.HANDOFF.HANDOFF_MESSAGE_PLACEHOLDER')
            "
            :rows="2"
          />
        </div>

        <div
          v-if="intents.length === 0"
          class="p-4 text-center text-sm text-n-slate-11 border border-n-slate-4 rounded-lg bg-n-slate-1"
        >
          {{ $t('SATURN.ASSISTANTS.HANDOFF.NO_INTENTS') }}
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end gap-3">
        <Button variant="outline" color="slate" @click="handleClose">
          {{ $t('SATURN.ASSISTANTS.HANDOFF.CANCEL') }}
        </Button>
        <Button
          variant="solid"
          color="blue"
          :is-loading="isSubmitting"
          :disabled="hasErrors"
          @click="handleSubmit"
        >
          {{ $t('SATURN.ASSISTANTS.HANDOFF.SAVE') }}
        </Button>
      </div>
    </template>
  </Dialog>
</template>
