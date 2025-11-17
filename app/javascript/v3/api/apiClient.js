import axios from 'axios';

const { apiHost = '' } = window.saturnConfig || {};
const wootAPI = axios.create({ baseURL: `${apiHost}/` });

export default wootAPI;
