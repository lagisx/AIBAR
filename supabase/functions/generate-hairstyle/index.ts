// Supabase Edge Function: generate-hairstyle
//
// Called by the Flutter app after a user attaches a photo + prompt in chat.
// Runs entirely server-side so the Replicate/Fal.ai API key never reaches
// the client:
//   1. Verifies the caller's Supabase JWT and looks up their subscription.
//   2. Rejects the request (HTTP 429) if the free-tier limit is reached.
//   3. Increments the usage counter and calls the AI provider.
//   4. Persists the result and inserts the assistant's chat message so the
//      client picks it up via Supabase Realtime.
//
// Deploy: `supabase functions deploy generate-hairstyle`
// Required secrets (`supabase secrets set ...`):
//   REPLICATE_API_TOKEN, REPLICATE_MODEL_VERSION
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-provided by Supabase)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const TIER_LIMITS: Record<string, number> = {
  free: 3,
  pro: 100,
  max: 1000,
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonResponse({ error: 'Missing Authorization header' }, 401);
    }

    // Client bound to the caller's JWT, used only to identify the user.
    const callerClient = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await callerClient.auth.getUser();
    if (userError || !user) {
      return jsonResponse({ error: 'Invalid or expired session' }, 401);
    }

    // Service-role client for privileged reads/writes (bypasses RLS).
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { source_photo_url, prompt_text, message_id, session_id } =
      await req.json();
    if (!source_photo_url || !prompt_text || !session_id) {
      return jsonResponse(
        { error: 'source_photo_url, prompt_text and session_id are required' },
        400,
      );
    }

    const { data: subscription, error: subError } = await admin
      .from('subscriptions')
      .select('tier, requests_used_this_period, period_reset_at')
      .eq('user_id', user.id)
      .maybeSingle();
    if (subError) {
      return jsonResponse({ error: subError.message }, 500);
    }

    const tier = subscription?.tier ?? 'free';
    const limit = TIER_LIMITS[tier] ?? TIER_LIMITS.free;
    const used = subscription?.requests_used_this_period ?? 0;

    if (used >= limit) {
      return jsonResponse(
        {
          error:
            'Лимит запросов на вашем тарифе исчерпан. Оформите подписку, чтобы продолжить.',
        },
        429,
      );
    }

    // Reserve one request slot before calling the (paid) AI provider.
    const { error: incrementError } = await admin
      .from('subscriptions')
      .upsert({
        user_id: user.id,
        tier,
        requests_used_this_period: used + 1,
      });
    if (incrementError) {
      return jsonResponse({ error: incrementError.message }, 500);
    }

    const { data: genRequest, error: genInsertError } = await admin
      .from('generation_requests')
      .insert({
        user_id: user.id,
        message_id: message_id ?? null,
        prompt_text,
        source_photo_url,
        status: 'pending',
      })
      .select()
      .single();
    if (genInsertError) {
      return jsonResponse({ error: genInsertError.message }, 500);
    }

    let resultUrls: string[];
    try {
      resultUrls = await callImageGenerationProvider(
        source_photo_url,
        prompt_text,
      );
    } catch (providerError) {
      await admin
        .from('generation_requests')
        .update({ status: 'failed' })
        .eq('id', genRequest.id);
      return jsonResponse(
        { error: `AI provider error: ${(providerError as Error).message}` },
        502,
      );
    }

    await admin
      .from('generation_requests')
      .update({ status: 'done', result_urls: resultUrls })
      .eq('id', genRequest.id);

    const { error: assistantMsgError } = await admin
      .from('chat_messages')
      .insert({
        user_id: user.id,
        session_id,
        role: 'assistant',
        type: 'image_result',
        content: JSON.stringify(resultUrls),
      });
    if (assistantMsgError) {
      return jsonResponse({ error: assistantMsgError.message }, 500);
    }

    await admin
      .from('chat_sessions')
      .update({ last_message_at: new Date().toISOString() })
      .eq('id', session_id);

    return jsonResponse({ result_urls: resultUrls });
  } catch (error) {
    return jsonResponse({ error: (error as Error).message }, 500);
  }
});

/// Calls Replicate (InstantID/IP-Adapter-style face-preserving model) with
/// the source photo + text prompt, and polls until the prediction finishes.
async function callImageGenerationProvider(
  sourcePhotoUrl: string,
  promptText: string,
): Promise<string[]> {
  const apiToken = Deno.env.get('REPLICATE_API_TOKEN');
  const modelVersion = Deno.env.get('REPLICATE_MODEL_VERSION');
  if (!apiToken || !modelVersion) {
    throw new Error(
      'REPLICATE_API_TOKEN / REPLICATE_MODEL_VERSION not configured',
    );
  }

  const createResponse = await fetch(
    'https://api.replicate.com/v1/predictions',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        version: modelVersion,
        input: {
          image: sourcePhotoUrl,
          prompt: promptText,
        },
      }),
    },
  );

  if (!createResponse.ok) {
    throw new Error(`Replicate create failed: ${await createResponse.text()}`);
  }

  let prediction = await createResponse.json();
  const pollUrl = prediction.urls?.get as string;

  const maxAttempts = 60; // ~2 minutes at 2s intervals
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    if (prediction.status === 'succeeded') {
      const output = prediction.output;
      return Array.isArray(output) ? output : [output];
    }
    if (prediction.status === 'failed' || prediction.status === 'canceled') {
      throw new Error(`Replicate prediction ${prediction.status}`);
    }

    await new Promise((resolve) => setTimeout(resolve, 2000));
    const pollResponse = await fetch(pollUrl, {
      headers: { Authorization: `Bearer ${apiToken}` },
    });
    prediction = await pollResponse.json();
  }

  throw new Error('Replicate prediction timed out');
}
