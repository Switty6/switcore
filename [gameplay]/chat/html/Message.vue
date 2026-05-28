<template>
    <div class="msg" :class="{ multiline }">
      <span class="msg-timestamp" v-if="timestamp">[{{ timestamp }}]</span><span v-html="textEscaped"></span>
    </div>
</template>

<script lang="ts" src="./Message.ts"></script>
