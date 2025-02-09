const cds = require('@sap/cds');

module.exports = cds.service.impl(async function (srv) {
    const { Books } = this.entities;

    srv.on('CREATE', 'Books', async (req) => {
        const { ID, title, stock } = req.data;

        // Ensure validFrom and validTo are NOT manually set
        delete req.data.validFrom;
        delete req.data.validTo;

        // Insert into Books (validFrom will be auto-generated)
        const newBook = await INSERT.into(Books).entries({
            ID,
            title,
            stock
        });

        return newBook;
    });
});
