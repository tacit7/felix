const puppeteer = require('puppeteer');

async function testOAuthFlow() {
  console.log('🚀 Starting Puppeteer OAuth Flow Test');
  console.log('====================================');
  
  let browser;
  let page;
  
  try {
    // Launch browser
    console.log('📱 Launching browser...');
    browser = await puppeteer.launch({ 
      headless: false, // Set to true for headless mode
      devtools: false,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    page = await browser.newPage();
    
    // Set viewport
    await page.setViewport({ width: 1280, height: 720 });
    
    // Monitor console logs
    page.on('console', msg => console.log('🌐 Browser Console:', msg.text()));
    
    // Monitor network requests
    page.on('request', request => {
      console.log('📡 Request:', request.method(), request.url());
    });
    
    page.on('response', response => {
      console.log('📥 Response:', response.status(), response.url());
    });
    
    // Test Step 1: Navigate to OAuth initiation
    console.log('\n🔗 Step 1: Navigating to OAuth initiation...');
    const oauthInitUrl = 'http://localhost:4001/api/auth/google';
    console.log(`   URL: ${oauthInitUrl}`);
    
    const response1 = await page.goto(oauthInitUrl, { 
      waitUntil: 'networkidle0',
      timeout: 10000 
    });
    console.log(`   ✅ Status: ${response1.status()}`);
    console.log(`   ✅ Final URL: ${page.url()}`);
    
    // Wait a moment for any redirects
    await page.waitForTimeout(2000);
    
    // Check current URL
    const currentUrl = page.url();
    console.log(`   📍 Current URL: ${currentUrl}`);
    
    // Test if we reached Google OAuth or got an error
    if (currentUrl.includes('accounts.google.com')) {
      console.log('   🎉 SUCCESS: Redirected to Google OAuth!');
      
      // Get page title
      const title = await page.title();
      console.log(`   📄 Page Title: ${title}`);
      
      // Check for sign-in elements
      const hasSignIn = await page.$('input[type="email"]') !== null;
      console.log(`   📧 Has email input: ${hasSignIn}`);
      
      // Take screenshot
      await page.screenshot({ 
        path: 'google-oauth-page.png', 
        fullPage: true 
      });
      console.log('   📸 Screenshot saved: google-oauth-page.png');
      
    } else if (currentUrl.includes('localhost:4001')) {
      console.log('   ⚠️  Still on Phoenix server');
      
      // Get page content to check for errors
      const content = await page.content();
      const title = await page.title();
      console.log(`   📄 Page Title: ${title}`);
      
      // Check for 404 or error content
      if (content.includes('404') || content.includes('Not Found')) {
        console.log('   ❌ ERROR: 404 Page Found');
        console.log('   📄 First 500 chars of page:');
        console.log(content.substring(0, 500));
      } else {
        console.log('   ✅ No 404 error detected');
      }
      
      // Take screenshot of error page
      await page.screenshot({ 
        path: 'phoenix-error-page.png', 
        fullPage: true 
      });
      console.log('   📸 Screenshot saved: phoenix-error-page.png');
      
    } else {
      console.log('   ❓ Unexpected URL');
    }
    
    // Test Step 2: Try direct /auth/google endpoint
    console.log('\n🔗 Step 2: Testing direct /auth/google endpoint...');
    const directOAuthUrl = 'http://localhost:4001/auth/google';
    console.log(`   URL: ${directOAuthUrl}`);
    
    const response2 = await page.goto(directOAuthUrl, { 
      waitUntil: 'networkidle0',
      timeout: 10000 
    });
    console.log(`   ✅ Status: ${response2.status()}`);
    console.log(`   ✅ Final URL: ${page.url()}`);
    
    await page.waitForTimeout(2000);
    
    const finalUrl = page.url();
    console.log(`   📍 Final URL: ${finalUrl}`);
    
    if (finalUrl.includes('accounts.google.com')) {
      console.log('   🎉 SUCCESS: Direct OAuth redirect works!');
    } else {
      console.log('   ⚠️  Direct OAuth redirect issue');
    }
    
  } catch (error) {
    console.error('❌ Error during OAuth test:', error.message);
    
    if (page) {
      // Take screenshot of error state
      try {
        await page.screenshot({ 
          path: 'oauth-error-screenshot.png', 
          fullPage: true 
        });
        console.log('📸 Error screenshot saved: oauth-error-screenshot.png');
      } catch (screenshotError) {
        console.log('Could not take error screenshot');
      }
    }
  } finally {
    if (browser) {
      console.log('\n🔒 Closing browser...');
      await browser.close();
    }
  }
  
  console.log('\n✅ Puppeteer OAuth test completed!');
}

// Handle command line arguments
const args = process.argv.slice(2);
const headless = args.includes('--headless');

if (headless) {
  console.log('Running in headless mode...');
}

// Run the test
testOAuthFlow()
  .then(() => {
    console.log('Test completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Test failed:', error);
    process.exit(1);
  });