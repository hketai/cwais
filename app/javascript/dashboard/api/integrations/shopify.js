/* global axios */

import ApiClient from '../ApiClient';

class ShopifyAPI extends ApiClient {
  constructor() {
    super('integrations/shopify', { accountScoped: true });
  }

  getHook() {
    return axios.get(`${this.url}`);
  }

  getOrders(contactId) {
    return axios.get(`${this.url}/orders`, {
      params: { contact_id: contactId },
    });
  }

  connectWithAccessKey({ shopDomain, accessKey }) {
    return axios.post(`${this.url}/connect`, {
      shop_domain: shopDomain,
      access_token: accessKey,
    });
  }

  disconnect() {
    return axios.delete(`${this.url}`);
  }

  testConnection() {
    return axios.get(`${this.url}/test`);
  }
}

export default new ShopifyAPI();
