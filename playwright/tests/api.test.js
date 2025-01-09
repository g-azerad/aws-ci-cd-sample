const { test, expect } = require('@playwright/test');

test.describe('API Counter Tests', () => {
    const apiBaseUrl = process.env.API_URL || 'http://localhost:5000';
    var initialValue;
    var incrementedValue;
    var decrementedValue;

    test('GET /counter should return the current value', async ({ request }) => {
        const response = await request.get(`${apiBaseUrl}/counter`);
        expect(response.ok()).toBeTruthy();
        const body = await response.json();
        expect(body).toHaveProperty('value');
        initialValue = body.value;
        console.log("Initial value: " + initialValue);
        expect(initialValue).toBeGreaterThanOrEqual(0);
    });

    test('PUT /increment should increase the counter', async ({ request }) => {
        const incrementResponse = await request.put(`${apiBaseUrl}/counter/increment`);
        expect(incrementResponse.ok()).toBeTruthy();
        const incrementedBody = await incrementResponse.json();
        expect(incrementedBody).toHaveProperty('value');
        incrementedValue = incrementedBody.value;
        console.log("Incremented value: " + incrementedValue);
        expect(incrementedValue).toBe(initialValue + 1);
    });

    test('PUT /decrement should decrease the counter', async ({ request }) => {
        const decrementResponse = await request.put(`${apiBaseUrl}/counter/decrement`);
        expect(decrementResponse.ok()).toBeTruthy();
        const decrementedBody = await decrementResponse.json();
        expect(decrementedBody).toHaveProperty('value');
        decrementedValue = decrementedBody.value;
        console.log("Decremented value: " + decrementedValue);
        expect(decrementedValue).toBeLessThan(incrementedValue);
        expect(decrementedValue).toBe(initialValue);
    });

    test('PUT /decrement should not decrease the counter under 0 after a reset', async ({ request }) => {
        const resetResponse = await request.put(`${apiBaseUrl}/counter/reset`);
        expect(resetResponse.ok()).toBeTruthy();
        const resetBody = await resetResponse.json();
        expect(resetBody).toHaveProperty('value');
        console.log("Reset value: " + resetBody.value);
        expect(resetBody.value).toBe(0);
        const decrementResponse = await request.put(`${apiBaseUrl}/counter/decrement`);
        expect(decrementResponse.ok()).toBeTruthy();
        const decrementedBody = await decrementResponse.json();
        expect(decrementedBody).toHaveProperty('value');
        console.log("Decremented value: " + resetBody.value);
        expect(decrementedBody.value).toBe(0);
    });
});
