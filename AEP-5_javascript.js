// AEP-5: Basic User Dashboard UI

// Frontend dashboard component
function displayUserProfile() {
    fetch('https://api.example.com/user/profile')
        .then(response => response.json())
        .then(data => {
            const profileDetails = document.getElementById('profile-details');
            profileDetails.innerHTML = `
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

// Basic UI styling
document.getElementById('profile-details').style.color = 'blue';

// Cross-browser testing
// No specific code needed, ensure dashboard loads without errors

// End of AEP-5_javascript.js