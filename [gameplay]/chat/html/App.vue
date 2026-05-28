<template>
    <div id="app">
      <div class="chat-window" :style="this.style" :class="{
          'animated': !showWindow && hideAnimated,
          'hidden': !showWindow
        }">

        <!-- SwitCore branding header -->
        <div class="chat-header">
          <svg class="chat-header-logo" viewBox="0 0 80 80" fill="none" xmlns="http://www.w3.org/2000/svg">
            <g style="transform-origin:40px 40px;animation:rCW 20s linear infinite">
              <polygon points="40,3 73,21 73,59 40,77 7,59 7,21" stroke="#00b4ff" stroke-width="0.8" fill="none" opacity="0.25"/>
              <circle cx="40" cy="3"  r="2" fill="#00b4ff" opacity="0.6"/>
              <circle cx="73" cy="21" r="2" fill="#00b4ff" opacity="0.6"/>
              <circle cx="73" cy="59" r="2" fill="#00b4ff" opacity="0.6"/>
              <circle cx="40" cy="77" r="2" fill="#00b4ff" opacity="0.6"/>
              <circle cx="7"  cy="59" r="2" fill="#00b4ff" opacity="0.6"/>
              <circle cx="7"  cy="21" r="2" fill="#00b4ff" opacity="0.6"/>
            </g>
            <g style="transform-origin:40px 40px;animation:rCCW 14s linear infinite">
              <polygon points="40,12 65,26 65,54 40,68 15,54 15,26" stroke="#00b4ff" stroke-width="0.6" fill="none" opacity="0.15"/>
            </g>
            <polygon style="animation:cPulse 3s ease-in-out infinite" points="40,20 58,30 58,50 40,60 22,50 22,30" fill="#00b4ff" opacity="0.85"/>
            <polygon points="40,27 53,34 53,46 40,53 27,46 27,34" fill="none" stroke="rgba(4,8,15,0.6)" stroke-width="1.5"/>
          </svg>
          <span class="chat-header-title">SwitCore</span>
        </div>

        <div class="chat-messages" ref="messages">
          <message v-for="msg in filteredMessages"
                   :templates="templates"
                   :multiline="msg.multiline"
                   :args="msg.args"
                   :params="msg.params"
                   :color="msg.color"
                   :template="msg.template"
                   :template-id="msg.templateId"
                   :timestamp="msg.timestamp"
                   :key="msg.id">
          </message>
        </div>
      </div>

      <div class="chat-input">
        <!-- Channel tabs - visible when input is open and channels exist -->
        <div class="chat-channel-tabs" v-show="showInput && visibleModes.length > 1">
          <span
            v-for="mode in visibleModes"
            :key="mode.name"
            class="channel-tab"
            :class="{ active: modes[modeIdx].name === mode.name }"
            :style="modes[modeIdx].name === mode.name ? { color: mode.color } : {}">
            {{ mode.displayName }}
          </span>
        </div>

        <div v-show="showInput" class="input" :class="{ 'no-tabs': visibleModes.length <= 1 }">
          <span class="prefix" :class="{ any: modes.length > 1 }" :style="{ color: modeColor }">{{modePrefix}}</span>
          <textarea v-model="message"
                    ref="input"
                    type="text"
                    autofocus
                    spellcheck="false"
                    rows="1"
                    @keyup.esc="hideInput"
                    @keyup="keyUp"
                    @keydown="keyDown"
                    @keypress.enter.prevent="send">
          </textarea>
        </div>
        <suggestions :message="message" :suggestions="suggestions">
        </suggestions>
        <div class="chat-hide-state" v-show="showHideState">
          {{hideStateString}}
        </div>
      </div>
    </div>
</template>

<script lang="ts" src="./App.ts"></script>

