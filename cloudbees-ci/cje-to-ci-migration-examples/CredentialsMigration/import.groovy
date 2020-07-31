import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.DomainCredentials
import com.trilead.ssh2.crypto.Base64
import hudson.util.XStream2
import jenkins.model.Jenkins

// Paste the encoded message from the script on the source Jenkins
def encoded = []
if (!encoded) {
    return
}

// The message is decoded and unmarshaled
for (slice in encoded) {
    def decoded = new String(Base64.decode(slice.chars))
    def list = new XStream2().fromXML(decoded) as List<DomainCredentials>

    // Put all the domains from the list into system credentials
    def store = Jenkins.get().getExtensionList(SystemCredentialsProvider.class).first().getStore()
    for (domain in list) {
        for (credentials in domain.credentials) {
            println "Adding credentials: ${credentials.id}"
            store.addDomain(domain.getDomain(), credentials)
        }
    }
}
