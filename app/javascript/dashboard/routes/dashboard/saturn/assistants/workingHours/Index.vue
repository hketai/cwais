<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import SaturnPageLayout from 'dashboard/components-next/saturn/SaturnPageLayout.vue';
import saturnAssistantAPI from 'dashboard/api/saturn/assistant';
import Button from 'dashboard/components-next/button/Button.vue';
import parse from 'date-fns/parse';
import differenceInMinutes from 'date-fns/differenceInMinutes';
import getHours from 'date-fns/getHours';
import getMinutes from 'date-fns/getMinutes';

const route = useRoute();
const { t } = useI18n();

const assistantId = Number(route.params.assistantId);
const assistant = ref(null);
const isFetching = ref(false);
const isSubmitting = ref(false);

const defaultTimeSlot = [
  { day: 1, to: '', from: '', valid: false, openAllDay: false },
  { day: 2, to: '', from: '', valid: false, openAllDay: false },
  { day: 3, to: '', from: '', valid: false, openAllDay: false },
  { day: 4, to: '', from: '', valid: false, openAllDay: false },
  { day: 5, to: '', from: '', valid: false, openAllDay: false },
  { day: 6, to: '', from: '', valid: false, openAllDay: false },
  { day: 0, to: '', from: '', valid: false, openAllDay: false },
];

const dayNames = {
  1: t('SATURN.ASSISTANTS.WORKING_HOURS.DAYS.MONDAY'),
  2: t('SATURN.ASSISTANTS.WORKING_HOURS.DAYS.TUESDAY'),
  3: t('SATURN.ASSISTANTS.WORKING_HOURS.DAYS.WEDNESDAY'),
  4: t('SATURN.ASSISTANTS.WORKING_HOURS.DAYS.THURSDAY'),
  5: t('SATURN.ASSISTANTS.WORKING_HOURS.DAYS.FRIDAY'),
  6: t('SATURN.ASSISTANTS.WORKING_HOURS.DAYS.SATURDAY'),
  0: t('SATURN.ASSISTANTS.WORKING_HOURS.DAYS.SUNDAY'),
};

const slots = ref([...defaultTimeSlot]);

const hasError = computed(() => {
  return slots.value.filter(slot => slot.from && !slot.valid).length > 0;
});

function generateTimeSlots(step = 15) {
  const date = new Date(1970, 1, 1);
  const timeSlotArray = [];
  while (date.getDate() === 1) {
    timeSlotArray.push(
      date.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
      })
    );
    date.setMinutes(date.getMinutes() + step);
  }
  const lastSlot = '11:59 PM';
  if (!timeSlotArray.includes(lastSlot)) {
    timeSlotArray.push(lastSlot);
  }
  return timeSlotArray;
}

const timeSlots = generateTimeSlots(30);

function getTime(hour, minute) {
  const meridian = hour > 11 ? 'PM' : 'AM';
  const modHour = hour > 12 ? hour % 12 : hour || 12;
  const parsedHour = modHour < 10 ? `0${modHour}` : modHour;
  const parsedMinute = minute < 10 ? `0${minute}` : minute;
  return `${parsedHour}:${parsedMinute} ${meridian}`;
}

function timeSlotParse(workingHours) {
  if (!workingHours || !Array.isArray(workingHours)) {
    return defaultTimeSlot;
  }
  return workingHours.map(slot => {
    const {
      day_of_week: day,
      open_hour: openHour,
      open_minutes: openMinutes,
      close_hour: closeHour,
      close_minutes: closeMinutes,
      closed_all_day: closedAllDay,
      open_all_day: openAllDay,
    } = slot;
    const from = closedAllDay ? '' : getTime(openHour, openMinutes);
    const to = closedAllDay ? '' : getTime(closeHour, closeMinutes);

    return {
      day,
      to,
      from,
      valid: !closedAllDay,
      openAllDay,
    };
  });
}

function timeSlotTransform(timeSlotArray) {
  return timeSlotArray.map(slot => {
    const closed = slot.openAllDay ? false : !(slot.to && slot.from);
    const openAllDay = slot.openAllDay;
    let fromDate = '';
    let toDate = '';
    let openHour = '';
    let openMinutes = '';
    let closeHour = '';
    let closeMinutes = '';

    if (!closed) {
      fromDate = parse(slot.from, 'hh:mm a', new Date());
      toDate = parse(slot.to, 'hh:mm a', new Date());
      openHour = getHours(fromDate);
      openMinutes = getMinutes(fromDate);
      closeHour = getHours(toDate);
      closeMinutes = getMinutes(toDate);
    }

    return {
      day_of_week: slot.day,
      closed_all_day: closed,
      open_hour: openHour,
      open_minutes: openMinutes,
      close_hour: closeHour,
      close_minutes: closeMinutes,
      open_all_day: openAllDay,
    };
  });
}

function setDefaults() {
  if (assistant.value?.config?.working_hours) {
    const parsed = timeSlotParse(assistant.value.config.working_hours);
    slots.value = parsed;
  } else {
    slots.value = [...defaultTimeSlot];
  }
}

function onSlotUpdate(slotIndex, slotData) {
  slots.value = slots.value.map(item =>
    item.day === slotIndex ? slotData : item
  );
}

async function fetchAssistantData() {
  isFetching.value = true;
  try {
    const response = await saturnAssistantAPI.show(assistantId);
    assistant.value = response.data;
    setDefaults();
  } catch {
    useAlert('Asistan bilgileri yüklenemedi');
  } finally {
    isFetching.value = false;
  }
}

async function handleSubmit() {
  if (hasError.value) {
    useAlert(t('SATURN.ASSISTANTS.WORKING_HOURS.VALIDATION_ERROR'));
    return;
  }

  try {
    isSubmitting.value = true;
    // Çalışma saatleri varsa ve en az bir gün aktifse çalışma saatleri aktif
    const hasActiveDays = slots.value.some(slot => slot.from && slot.to);
    const workingHours = hasActiveDays ? timeSlotTransform(slots.value) : [];

    await saturnAssistantAPI.updateWorkingHours({
      assistantId,
      workingHours,
    });

    useAlert(t('SATURN.ASSISTANTS.WORKING_HOURS.SAVE_SUCCESS'));
    await fetchAssistantData();
  } catch (error) {
    const errorMessage =
      error?.response?.data?.error ||
      error?.message ||
      t('SATURN.ASSISTANTS.WORKING_HOURS.SAVE_ERROR');
    useAlert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
}

watch(
  () => assistant.value,
  () => {
    if (assistant.value) {
      setDefaults();
    }
  },
  { deep: true }
);

onMounted(() => {
  fetchAssistantData();
});
</script>

<template>
  <SaturnPageLayout
    :page-title="
      assistant?.name
        ? `${assistant.name} - ${$t('SATURN.ASSISTANTS.WORKING_HOURS.TITLE')}`
        : $t('SATURN.ASSISTANTS.WORKING_HOURS.TITLE')
    "
    :action-permissions="['administrator']"
    :enable-pagination="false"
    :is-loading="isFetching"
    :has-no-data="false"
    :total-records="0"
    :feature-flag-key="FEATURE_FLAGS.SATURN"
    :return-path="{ name: 'saturn_assistants_edit', params: { assistantId } }"
  >
    <template #contentArea>
      <div
        class="flex flex-col gap-6 p-6 bg-n-slate-1 rounded-lg border border-n-slate-4"
      >
        <div>
          <p class="text-sm text-n-slate-11 mb-4">
            {{ $t('SATURN.ASSISTANTS.WORKING_HOURS.DESCRIPTION') }}
          </p>
        </div>

        <div class="flex flex-col gap-4">
          <div
            v-for="timeSlot in slots"
            :key="timeSlot.day"
            class="flex items-center gap-4 p-3 border-b border-n-slate-4"
          >
            <div class="flex items-center gap-2 min-w-[8rem]">
              <input
                v-model="timeSlot.from"
                :checked="!!timeSlot.from"
                type="checkbox"
                class="cursor-pointer"
                @change="
                  onSlotUpdate(timeSlot.day, {
                    ...timeSlot,
                    from: $event.target.checked ? '09:00 AM' : '',
                    to: $event.target.checked ? '05:00 PM' : '',
                    valid: $event.target.checked,
                    openAllDay: false,
                  })
                "
              />
              <span class="text-sm font-medium text-n-slate-12">
                {{ dayNames[timeSlot.day] }}
              </span>
            </div>

            <div
              v-if="timeSlot.from && timeSlot.to"
              class="flex items-center gap-4 flex-1"
            >
              <label class="flex items-center gap-2 cursor-pointer">
                <input
                  v-model="timeSlot.openAllDay"
                  type="checkbox"
                  class="cursor-pointer"
                  @change="
                    onSlotUpdate(timeSlot.day, {
                      ...timeSlot,
                      openAllDay: $event.target.checked,
                      from: $event.target.checked ? '12:00 AM' : '09:00 AM',
                      to: $event.target.checked ? '11:59 PM' : '05:00 PM',
                      valid: true,
                    })
                  "
                />
                <span class="text-sm text-n-slate-11">
                  {{ $t('SATURN.ASSISTANTS.WORKING_HOURS.ALL_DAY') }}
                </span>
              </label>

              <select
                v-model="timeSlot.from"
                :disabled="timeSlot.openAllDay"
                class="px-3 py-2 text-sm border border-n-slate-6 rounded-lg bg-n-slate-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-blue-9 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-n-slate-3 dark:border-n-slate-7"
                @change="
                  e => {
                    const fromDate = parse(
                      e.target.value,
                      'hh:mm a',
                      new Date()
                    );
                    const toDate = parse(timeSlot.to, 'hh:mm a', new Date());
                    const valid =
                      differenceInMinutes(toDate, fromDate) / 60 > 0;
                    onSlotUpdate(timeSlot.day, {
                      ...timeSlot,
                      from: e.target.value,
                      valid,
                    });
                  }
                "
              >
                <option v-for="slot in timeSlots" :key="slot" :value="slot">
                  {{ slot }}
                </option>
              </select>

              <span class="text-n-slate-11">{{
                $t('SATURN.ASSISTANTS.WORKING_HOURS.TIME_SEPARATOR')
              }}</span>

              <select
                v-model="timeSlot.to"
                :disabled="timeSlot.openAllDay"
                class="px-3 py-2 text-sm border border-n-slate-6 rounded-lg bg-n-slate-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-blue-9 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-n-slate-3 dark:border-n-slate-7"
                @change="
                  e => {
                    if (e.target.value === '12:00 AM') {
                      onSlotUpdate(timeSlot.day, {
                        ...timeSlot,
                        to: e.target.value,
                        valid: true,
                      });
                    } else {
                      const fromDate = parse(
                        timeSlot.from,
                        'hh:mm a',
                        new Date()
                      );
                      const toDate = parse(
                        e.target.value,
                        'hh:mm a',
                        new Date()
                      );
                      const valid =
                        differenceInMinutes(toDate, fromDate) / 60 > 0;
                      onSlotUpdate(timeSlot.day, {
                        ...timeSlot,
                        to: e.target.value,
                        valid,
                      });
                    }
                  }
                "
              >
                <option
                  v-for="slot in timeSlots.filter(s => s !== '12:00 AM')"
                  :key="slot"
                  :value="slot"
                >
                  {{ slot }}
                </option>
                <option value="12:00 AM">
                  {{ $t('SATURN.ASSISTANTS.WORKING_HOURS.MIDNIGHT') }}
                </option>
              </select>

              <div
                v-if="!timeSlot.valid && timeSlot.from && timeSlot.to"
                class="text-xs text-n-ruby-9"
              >
                {{ $t('SATURN.ASSISTANTS.WORKING_HOURS.INVALID_TIME') }}
              </div>
            </div>

            <div v-else class="flex-1 text-sm text-n-slate-11">
              <span>{{
                $t('SATURN.ASSISTANTS.WORKING_HOURS.UNAVAILABLE')
              }}</span>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t border-n-slate-4">
          <Button
            variant="solid"
            color="blue"
            :is-loading="isSubmitting"
            :disabled="hasError"
            @click="handleSubmit"
          >
            {{ $t('SATURN.ASSISTANTS.WORKING_HOURS.SAVE') }}
          </Button>
        </div>
      </div>
    </template>
  </SaturnPageLayout>
</template>
