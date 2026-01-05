const https = require('https');

const data = JSON.stringify({
  data: {
    prompt: "Say hello in a creative way!"
  }
});

const options = {
  hostname: 'us-central1-inkos-f58f1.cloudfunctions.net',
  port: 443,
  path: '/chat',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('Testing chat function...\n');

const req = https.request(options, (res) => {
  let responseData = '';

  res.on('data', (chunk) => {
    responseData += chunk;
  });

  res.on('end', () => {
    console.log('Response:');
    console.log(JSON.stringify(JSON.parse(responseData), null, 2));
  });
});

req.on('error', (error) => {
  console.error('Error:', error);
});

req.write(data);
req.end();
