<script setup>
import { reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';

const props = defineProps({
  formMode: {
    type: String,
    required: true,
    validator: value => ['modify', 'create'].includes(value),
  },
  assistantData: {
    type: Object,
    default: () => ({}),
  },
  isSubmitting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const defaultFormData = {
  assistantName: '',
  assistantDescription: '',
  temperature: 0.7,
};

const formData = reactive({ ...defaultFormData });

const rules = {
  assistantName: { required, minLength: minLength(1) },
  assistantDescription: { required, minLength: minLength(1) },
};

const validator = useVuelidate(rules, formData);

const isSubmitting = computed(() => props.isSubmitting);

const getFieldError = (field, errorKey) => {
  return validator.value[field].$error
    ? t(`SATURN.ASSISTANTS.FORM.${errorKey}.ERROR`)
    : '';
};

const fieldErrors = computed(() => ({
  assistantName: getFieldError('assistantName', 'NAME'),
  assistantDescription: getFieldError('assistantDescription', 'DESCRIPTION'),
}));

const cancelForm = () => emit('cancel');

const buildAssistantPayload = () => ({
  name: formData.assistantName,
  description: formData.assistantDescription,
  config: {
    temperature: formData.temperature || 0.7,
  },
});

const submitForm = async () => {
  const isValid = await validator.value.$validate();
  if (!isValid) {
    return;
  }

  emit('submit', buildAssistantPayload());
};

const populateFormFromAssistant = assistant => {
  if (!assistant) return;

  const { name, description, config } = assistant;

  Object.assign(formData, {
    assistantName: name,
    assistantDescription: description,
    temperature: config?.temperature || 0.7,
  });
};

watch(
  () => props.assistantData,
  newAssistant => {
    if (props.formMode === 'modify' && newAssistant) {
      populateFormFromAssistant(newAssistant);
    }
  },
  { immediate: true }
);
</script>

<template>
  <form class="saturn-form" @submit.prevent="submitForm">
    <div class="saturn-form-section">
      <Input
        v-model="formData.assistantName"
        :label="t('SATURN.ASSISTANTS.FORM.NAME.LABEL')"
        :placeholder="t('SATURN.ASSISTANTS.FORM.NAME.PLACEHOLDER')"
        :message="fieldErrors.assistantName"
        :message-type="fieldErrors.assistantName ? 'error' : 'info'"
        class="saturn-input"
      />
    </div>

    <div class="saturn-form-section">
      <Editor
        v-model="formData.assistantDescription"
        :label="t('SATURN.ASSISTANTS.FORM.DESCRIPTION.LABEL')"
        :placeholder="t('SATURN.ASSISTANTS.FORM.DESCRIPTION.PLACEHOLDER')"
        :message="fieldErrors.assistantDescription"
        :message-type="fieldErrors.assistantDescription ? 'error' : 'info'"
        class="saturn-editor"
      />
    </div>

    <div class="saturn-form-section">
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('SATURN.ASSISTANTS.FORM.TEMPERATURE.LABEL') }}
        </label>
        <div class="flex items-center gap-4">
          <input
            v-model.number="formData.temperature"
            type="range"
            min="0"
            max="1"
            step="0.1"
            class="flex-1"
          />
          <span class="text-sm text-n-slate-12 min-w-[3rem]">{{
            formData.temperature
          }}</span>
        </div>
        <p class="text-sm text-n-slate-11 italic">
          {{ t('SATURN.ASSISTANTS.FORM.TEMPERATURE.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <div class="saturn-form-actions">
      <Button
        type="button"
        variant="faded"
        color="slate"
        :label="t('SATURN.FORM.CANCEL')"
        class="saturn-button-cancel"
        @click="cancelForm"
      />
      <Button
        type="submit"
        :label="t(`SATURN.FORM.${formMode.toUpperCase()}`)"
        class="saturn-button-submit"
        :is-loading="isSubmitting"
        :disabled="isSubmitting"
      />
    </div>
  </form>
</template>
