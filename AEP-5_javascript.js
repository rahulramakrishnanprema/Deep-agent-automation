// AEP-5: Basic User Dashboard UI

// Create frontend dashboard component
function displayUserProfile() {
    fetch('https://api.example.com/user/profile')
        .then(response => response.json())
        .then(data => {
            const profileElement = document.getElementById('user-profile');
            profileElement.innerHTML = `
                <p>Name: ${data.name}</p>
                <p>Email: ${data.email}</p>
                <p>Role: ${data.role}</p>
            `;
        })
        .catch(error => {
            console.error('Error fetching user profile:', error);
        });
}

// Integrate user profile API
displayUserProfile();

// Apply basic UI styling
document.getElementById('user-profile').style.backgroundColor = '#f0f0f0';
document.getElementById('user-profile').style.padding = '10px';
document.getElementById('user-profile').style.border = '1px solid #ccc';

// Cross-browser testing
// No specific code needed for this task. Make sure to test on different browsers.

// End of AEP-5_javascript.js file.